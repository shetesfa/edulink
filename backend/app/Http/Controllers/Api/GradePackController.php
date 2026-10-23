<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;
use ZipArchive;

class GradePackController extends Controller
{
    private string $packsDir;

    public function __construct()
    {
        $this->packsDir = storage_path('app/grade_packs');
        if (!File::exists($this->packsDir)) {
            File::makeDirectory($this->packsDir, 0755, true);
        }
    }

    /**
     * POST /api/grade-packs/import
     * Imports a Grade Pack ZIP file (e.g. EduLink_Grade_9_Offline_Pack.zip)
     */
    public function import(Request $request): JsonResponse
    {
        $request->validate([
            'file' => 'nullable|file|mimes:zip|max:51200', // up to 50MB
            'path' => 'nullable|string', // or local path on PC server
        ]);

        $zipPath = null;
        $tempFile = false;

        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $zipPath = $file->getRealPath();
        } elseif ($request->filled('path')) {
            $candidate = $request->input('path');
            if (File::exists($candidate)) {
                $zipPath = $candidate;
            } elseif (File::exists(base_path('../' . $candidate))) {
                $zipPath = base_path('../' . $candidate);
            }
        }

        if (!$zipPath || !File::exists($zipPath)) {
            // Auto-check for default EduLink_Grade_9_Offline_Pack (1).zip or EduLink_Grade_9_Offline_Pack.zip in workspace
            $defaultPacks = [
                base_path('../EduLink_Grade_9_Offline_Pack (1).zip'),
                base_path('../EduLink_Grade_9_Offline_Pack.zip'),
            ];
            foreach ($defaultPacks as $dp) {
                if (File::exists($dp)) {
                    $zipPath = $dp;
                    break;
                }
            }
        }

        if (!$zipPath || !File::exists($zipPath)) {
            return response()->json([
                'success' => false,
                'message' => 'Grade Pack ZIP file not found. Please upload a valid .zip file.'
            ], 422);
        }

        $zip = new ZipArchive();
        if ($zip->open($zipPath) !== true) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to open ZIP archive.'
            ], 500);
        }

        // Find manifest.json
        $manifestIndex = -1;
        $manifestPathInZip = '';
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $name = $zip->getNameIndex($i);
            if (strtolower(basename($name)) === 'manifest.json') {
                $manifestIndex = $i;
                $manifestPathInZip = $name;
                break;
            }
        }

        if ($manifestIndex === -1) {
            $zip->close();
            return response()->json([
                'success' => false,
                'message' => 'Invalid Grade Pack: manifest.json not found inside ZIP archive.'
            ], 422);
        }

        $manifestJson = $zip->getFromIndex($manifestIndex);
        $manifest = json_decode($manifestJson, true);
        if (!is_array($manifest)) {
            $zip->close();
            return response()->json([
                'success' => false,
                'message' => 'Invalid manifest.json format.'
            ], 422);
        }

        $grade = $manifest['grade'] ?? 9;
        $packName = $manifest['pack_name'] ?? "EduLink Grade {$grade} Offline Pack";
        $packId = 'g' . $grade . '_pack_' . md5($packName);
        $targetExtractDir = $this->packsDir . '/' . $packId;

        if (File::exists($targetExtractDir)) {
            File::deleteDirectory($targetExtractDir);
        }
        File::makeDirectory($targetExtractDir, 0755, true);

        // Extract ZIP
        $zip->extractTo($targetExtractDir);
        $zip->close();

        // Save metadata
        $meta = [
            'pack_id'      => $packId,
            'pack_name'    => $packName,
            'grade'        => $grade,
            'version'      => $manifest['version'] ?? '1.0.0',
            'imported_at'  => date('Y-m-d H:i:s'),
            'source_file'  => basename($zipPath),
            'extract_dir'  => $targetExtractDir,
            'manifest'     => $manifest,
        ];
        File::put($targetExtractDir . '/_meta.json', json_encode($meta, JSON_PRETTY_PRINT));

        // Scan subjects and units
        $summary = $this->scanPackDetails($targetExtractDir);

        return response()->json([
            'success'  => true,
            'message'  => "Grade {$grade} Offline Pack imported successfully!",
            'pack'     => array_merge($meta, $summary),
        ]);
    }

    /**
     * GET /api/grade-packs
     * List all installed Grade Packs
     */
    public function index(): JsonResponse
    {
        $directories = File::directories($this->packsDir);
        $packs = [];

        foreach ($directories as $dir) {
            $metaFile = $dir . '/_meta.json';
            if (File::exists($metaFile)) {
                $meta = json_decode(File::get($metaFile), true);
                if (is_array($meta)) {
                    $summary = $this->scanPackDetails($dir);
                    $packs[] = array_merge($meta, $summary);
                }
            }
        }

        return response()->json([
            'success' => true,
            'count'   => count($packs),
            'packs'   => $packs,
        ]);
    }

    /**
     * GET /api/grade-packs/{grade}/{subject}/units
     * List available units and unit summaries for a grade and subject
     */
    public function subjectUnits(int $grade, string $subject): JsonResponse
    {
        $subjectKey = strtolower(trim($subject));
        $packDir = $this->findPackDirForGrade($grade);

        if (!$packDir) {
            return response()->json([
                'success' => false,
                'message' => "No installed Grade {$grade} Offline Pack found."
            ], 444);
        }

        $subjectPath = $this->findSubjectPathInDir($packDir, $subjectKey);
        if (!$subjectPath || !File::exists($subjectPath)) {
            return response()->json([
                'success' => false,
                'message' => "Subject '{$subject}' content not found in Grade {$grade} Pack."
            ], 404);
        }

        $unitDirs = File::directories($subjectPath);
        sort($unitDirs);
        $units = [];

        foreach ($unitDirs as $uDir) {
            $folderName = basename($uDir);
            if (!preg_match('/unit_(\d+)/i', $folderName, $m)) continue;

            $unitNum = (int)$m[1];
            $summaryFile = $uDir . '/unit_summary.json';
            $summaryData = File::exists($summaryFile) ? json_decode(File::get($summaryFile), true) : null;

            $units[] = [
                'unit_number' => $unitNum,
                'folder'      => $folderName,
                'unit_title'  => $summaryData['unit_title'] ?? "Unit {$unitNum}",
                'overview'    => $summaryData['unit_overview'] ?? $summaryData['overview'] ?? '',
                'has_concepts'=> File::exists($uDir . '/concepts.json'),
                'has_glossary'=> File::exists($uDir . '/glossary.json'),
                'has_exercises'=> File::exists($uDir . '/exercises.json'),
                'has_examples'=> File::exists($uDir . '/worked_examples.json'),
                'has_quiz'    => File::exists($uDir . '/practice_quiz.json'),
            ];
        }

        return response()->json([
            'success' => true,
            'grade'   => $grade,
            'subject' => $subject,
            'units'   => $units,
        ]);
    }

    /**
     * GET /api/grade-packs/{grade}/{subject}/unit/{unit}
     * Get complete offline unit content (summary, concepts, glossary, exercises, worked examples, practice quiz)
     */
    public function unitContent(int $grade, string $subject, int $unit): JsonResponse
    {
        $subjectKey = strtolower(trim($subject));
        $packDir = $this->findPackDirForGrade($grade);

        if (!$packDir) {
            return response()->json(['success' => false, 'message' => "Grade {$grade} Pack not installed."], 404);
        }

        $subjectPath = $this->findSubjectPathInDir($packDir, $subjectKey);
        if (!$subjectPath) {
            return response()->json(['success' => false, 'message' => "Subject '{$subject}' not found."], 404);
        }

        $padUnit = str_pad($unit, 2, '0', STR_PAD_LEFT);
        $unitDir = $subjectPath . '/unit_' . $padUnit;

        if (!File::exists($unitDir)) {
            // Check without padding
            $unitDir = $subjectPath . '/unit_' . $unit;
        }

        if (!File::exists($unitDir)) {
            return response()->json(['success' => false, 'message' => "Unit {$unit} not found."], 404);
        }

        $readJson = function($filename) use ($unitDir) {
            $path = $unitDir . '/' . $filename;
            if (File::exists($path)) {
                $data = json_decode(File::get($path), true);
                return is_array($data) ? $data : null;
            }
            return null;
        };

        return response()->json([
            'success'         => true,
            'grade'           => $grade,
            'subject'         => $subject,
            'unit_number'     => $unit,
            'summary'         => $readJson('unit_summary.json'),
            'concepts'        => $readJson('concepts.json'),
            'glossary'        => $readJson('glossary.json'),
            'exercises'       => $readJson('exercises.json'),
            'worked_examples' => $readJson('worked_examples.json'),
            'practice_quiz'   => $readJson('practice_quiz.json'),
        ]);
    }

    /**
     * GET /api/grade-packs/search?q=query&grade=9
     * Offline search across all installed Grade Pack concepts & definitions
     */
    public function search(Request $request): JsonResponse
    {
        $query = trim($request->input('q', ''));
        $grade = (int)$request->input('grade', 9);

        if (mb_strlen($query) < 2) {
            return response()->json(['success' => false, 'message' => 'Query too short'], 422);
        }

        $packDir = $this->findPackDirForGrade($grade);
        if (!$packDir) {
            return response()->json(['success' => true, 'results' => [], 'count' => 0]);
        }

        $results = [];
        $files = File::allFiles($packDir);

        foreach ($files as $file) {
            if (!str_ends_with($file->getFilename(), '.json') || $file->getFilename() === '_meta.json') continue;

            $content = File::get($file->getRealPath());
            if (stripos($content, $query) === false) continue;

            $data = json_decode($content, true);
            if (!is_array($data)) continue;

            // Extract matching items
            $subject = $data['subject'] ?? basename(dirname(dirname($file->getRealPath())));
            $unitNum = $data['unit_number'] ?? null;

            if (!empty($data['concepts'])) {
                foreach ($data['concepts'] as $c) {
                    if (stripos($c['name'] ?? '', $query) !== false || stripos($c['simple_definition'] ?? '', $query) !== false || stripos($c['deep_explanation'] ?? '', $query) !== false) {
                        $results[] = [
                            'type'        => 'concept',
                            'subject'     => $subject,
                            'unit_number' => $unitNum,
                            'title'       => $c['name'] ?? 'Concept',
                            'snippet'     => $c['simple_definition'] ?? '',
                            'source_page' => $c['source_pages'] ?? $c['source_page'] ?? null,
                            'data'        => $c,
                        ];
                    }
                }
            }

            if (!empty($data['exercises'])) {
                foreach ($data['exercises'] as $ex) {
                    if (stripos($ex['question'] ?? '', $query) !== false || stripos($ex['correct_answer'] ?? '', $query) !== false) {
                        $results[] = [
                            'type'        => 'exercise',
                            'subject'     => $subject,
                            'unit_number' => $unitNum,
                            'title'       => 'Exercise Problem',
                            'snippet'     => $ex['question'] ?? '',
                            'source_page' => $ex['source_page'] ?? null,
                            'data'        => $ex,
                        ];
                    }
                }
            }
        }

        return response()->json([
            'success' => true,
            'count'   => count($results),
            'results' => array_slice($results, 0, 20),
        ]);
    }

    /**
     * DELETE /api/grade-packs/{pack_id}
     */
    public function destroy(string $packId): JsonResponse
    {
        $targetDir = $this->packsDir . '/' . $packId;
        if (File::exists($targetDir)) {
            File::deleteDirectory($targetDir);
            return response()->json(['success' => true, 'message' => 'Grade Pack uninstalled successfully.']);
        }
        return response()->json(['success' => false, 'message' => 'Grade Pack not found.'], 404);
    }

    // ── Private Helpers ──────────────────────────────────────────────────────

    private function findPackDirForGrade(int $grade): ?string
    {
        $directories = File::directories($this->packsDir);
        foreach ($directories as $dir) {
            $metaFile = $dir . '/_meta.json';
            if (File::exists($metaFile)) {
                $meta = json_decode(File::get($metaFile), true);
                if (isset($meta['grade']) && (int)$meta['grade'] === $grade) {
                    return $dir;
                }
            }
        }
        return null;
    }

    private function findSubjectPathInDir(string $packDir, string $subjectKey): ?string
    {
        // 1. Direct match inside packDir
        if (File::exists($packDir . '/' . $subjectKey)) {
            return $packDir . '/' . $subjectKey;
        }

        // 2. Direct match inside nested subfolder (e.g. EduLink_Grade_9_Offline_Pack/subject)
        $subdirs = File::directories($packDir);
        foreach ($subdirs as $sDir) {
            if (File::exists($sDir . '/' . $subjectKey)) {
                return $sDir . '/' . $subjectKey;
            }
            if (strtolower(basename($sDir)) === $subjectKey) {
                return $sDir;
            }
        }

        return null;
    }

    private function scanPackDetails(string $dir): array
    {
        $files = File::allFiles($dir);
        $totalSize = 0;
        $subjectsFound = [];
        $unitsCount = 0;

        foreach ($files as $f) {
            $totalSize += $f->getSize();
            $path = $f->getRealPath();
            if (preg_match('/unit_(\d+)/i', $path)) {
                $unitsCount++;
            }
            $parts = explode(DIRECTORY_SEPARATOR, $path);
            foreach ($parts as $p) {
                if (in_array(strtolower($p), ['biology', 'chemistry', 'mathematics', 'physics', 'english', 'history', 'geography', 'civics', 'economics', 'information_technology'])) {
                    $subjectsFound[strtolower($p)] = true;
                }
            }
        }

        return [
            'total_size_bytes' => $totalSize,
            'size_formatted'   => round($totalSize / 1024, 1) . ' KB',
            'subjects'         => array_keys($subjectsFound),
            'units_count'      => intdiv($unitsCount, 5), // approximate unit count across files
        ];
    }
}
