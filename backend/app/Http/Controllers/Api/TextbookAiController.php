<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AiRouterService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\File;

/**
 * TextbookAiController
 * ─────────────────────────────────────────────────────────────────────────────
 * Handles all textbook-AI queries.
 *
 * Flow:
 *   1. Receive student question + selected grades/subjects
 *   2. Search local SQLite textbook database for relevant pages
 *   3. Build a teaching prompt with the found content
 *   4. Send to Ollama (local AI) and stream response back
 *   5. Include page image references in the response
 */
class TextbookAiController extends Controller
{
    // ── Config ──────────────────────────────────────────────────────────────
    private string $dbPath;
    private string $ollamaUrl;
    private string $ollamaModel;
    private string $imagesBasePath;
    private AiRouterService $aiRouter;

    public function __construct(AiRouterService $aiRouter)
    {
        $this->aiRouter     = $aiRouter;
        $this->dbPath       = base_path('../textbook_ai/data/textbooks.db');
        $this->ollamaUrl    = env('OLLAMA_URL', 'http://localhost:11434');
        $this->ollamaModel  = env('OLLAMA_MODEL', 'qwen2.5:0.5b');
        $this->imagesBasePath = base_path('../textbook_ai/data/page_images');
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  POST /api/ai/textbook — Main query endpoint
    // ─────────────────────────────────────────────────────────────────────────
    public function query(Request $request): JsonResponse
    {
        // Allow long Ollama responses — PHP default 60s is too short
        set_time_limit(300);

        $request->validate([
            'question'   => 'required|string|max:1000',
            'grades'     => 'required|array|min:1',
            'grades.*'   => 'integer|between:1,12',
            'subjects'   => 'nullable|array',
            'subjects.*' => 'nullable|string|max:100',
            'language'   => 'nullable|string|in:en,am,om,ti',
            'history'    => 'nullable|array',
        ]);

        $question = trim($request->input('question'));
        $grades   = $request->input('grades');    // e.g. [9]
        $subjects = $request->input('subjects', []); // e.g. ['Biology']
        $language = $request->input('language', 'en');
        $history  = $request->input('history', []);

        // Auto-detect Amharic Ethiopic characters in question
        if (preg_match('/[\x{1200}-\x{137F}]/u', $question)) {
            $language = 'am';
        }

        // 1. Detect Intent
        $intent = $this->detectIntent($question);

        // 2. Resolve Conversation Context
        $context = $this->resolveContext($question, $history, $intent);
        $searchQuery   = $context['search_query'];
        $resolvedTopic = $context['resolved_topic'];

        // Check if student is asking for Exercise solutions (e.g. "maths unit 1 exercise 1.2" or "help with exercise")
        if (preg_match('/(?i)exercise/i', $question) || preg_match('/(?i)unit\s*\d+\s*exercise/i', $question)) {
            $exResponse = $this->handleGradePackExerciseRequest($question, $grades, $subjects, $language);
            if ($exResponse !== null) {
                return $exResponse;
            }
        }

        // 3. Search the textbook database
        $pages = $this->searchTextbook($searchQuery, $grades, $subjects);

        // If no pages match the search query, fallback to searching just the resolved topic
        if (empty($pages) && !empty($resolvedTopic) && $searchQuery !== $resolvedTopic) {
            $pages = $this->searchTextbook($resolvedTopic, $grades, $subjects);
        }

        if (empty($pages)) {
            return $this->fallbackResponse($question, $grades, $language);
        }

        $suggestedActions = ['Explain more', 'Give example', 'Quiz me', 'Show textbook page'];

        // 4. Build teaching prompt
        $prompt = $this->buildTeachingPrompt($question, $pages, $grades, $language, $intent, $resolvedTopic);

        // 5. Try Ollama (Fast check: max 2s connect timeout, 15s generation timeout)
        $aiResponse = $this->callOllama($prompt);

        if ($aiResponse['success']) {
            return response()->json([
                'success'           => true,
                'response'          => $aiResponse['text'],
                'provider'          => 'EduLink AI (Local Ollama ' . $this->ollamaModel . ')',
                'pages'             => $this->formatPageRefs($pages),
                'grades'            => $grades,
                'intent'            => $intent,
                'suggested_actions' => $suggestedActions,
            ]);
        }

        // 6. Try Cloud AI Router (Gemini, Groq, Cohere, Mistral, HuggingFace)
        $routerResponse = $this->aiRouter->ask($prompt, ['language' => $language]);
        if ($routerResponse['success'] && !str_contains($routerResponse['provider'] ?? '', 'EduLink Educational AI')) {
            return response()->json([
                'success'           => true,
                'response'          => $routerResponse['response'],
                'provider'          => $routerResponse['provider'] ?? 'EduLink Cloud AI',
                'pages'             => $this->formatPageRefs($pages),
                'grades'            => $grades,
                'intent'            => $intent,
                'suggested_actions' => $suggestedActions,
            ]);
        }

        // 7. Ollama & Cloud offline — return instant textbook database search result
        return $this->searchOnlyResponse($pages, $question, $intent, $resolvedTopic);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  GET /api/ai/textbook/search — Search pages without AI
    // ─────────────────────────────────────────────────────────────────────────
    public function search(Request $request): JsonResponse
    {
        $query    = $request->input('q', '');
        $grades   = $request->input('grades') ? explode(',', $request->input('grades')) : [];
        $subject  = $request->input('subject', '');

        if (empty($query)) {
            return response()->json(['success' => false, 'message' => 'Query required'], 422);
        }

        $pages = $this->searchTextbook($query, $grades, $subject ? [$subject] : []);

        return response()->json([
            'success' => true,
            'results' => $this->formatPageRefs($pages),
            'count'   => count($pages),
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  GET /api/ai/textbook/page-image/{grade}/{subject}/{page}
    // ─────────────────────────────────────────────────────────────────────────
    public function pageImage(Request $request, int $grade, string $subject, int $page): mixed
    {
        $padPage = str_pad($page, 4, '0', STR_PAD_LEFT);
        $subjectDir = str_replace([' ', '&'], ['_', 'and'], $subject);
        $resolvedPath = null;

        // 1. Check SQLite database for stored image_path
        $db = $this->openDb();
        if ($db) {
            $stmt = $db->prepare("SELECT image_path FROM textbook_pages WHERE grade = ? AND (subject LIKE ? OR subject LIKE ?) AND page_number = ? LIMIT 1");
            $stmt->execute([$grade, "%{$subject}%", "%General%", $page]);
            $row = $stmt->fetch(\PDO::FETCH_ASSOC);
            if (!empty($row['image_path'])) {
                $dbImg = $row['image_path'];
                if (file_exists($dbImg)) {
                    $resolvedPath = $dbImg;
                } elseif (file_exists($this->imagesBasePath . '/' . $dbImg)) {
                    $resolvedPath = $this->imagesBasePath . '/' . $dbImg;
                }
            }
        }

        // 2. Direct path check
        if (!$resolvedPath) {
            $candidatePath = $this->imagesBasePath . "/grade_{$grade}/{$subjectDir}/p{$padPage}.jpg";
            if (file_exists($candidatePath)) {
                $resolvedPath = $candidatePath;
            }
        }

        // 3. Folder search fallback
        if (!$resolvedPath) {
            $gradeFolder = $this->imagesBasePath . "/grade_{$grade}";
            if (file_exists($gradeFolder)) {
                $dirs = glob($gradeFolder . '/*', GLOB_ONLYDIR);
                foreach ($dirs as $dir) {
                    $testFile = $dir . "/p{$padPage}.jpg";
                    if (file_exists($testFile)) {
                        $resolvedPath = $testFile;
                        break;
                    }
                }
            }
        }

        if (!$resolvedPath || !file_exists($resolvedPath)) {
            return response()->json(['error' => 'Page image not found', 'grade' => $grade, 'subject' => $subject, 'page' => $page], 404);
        }

        return response()->file($resolvedPath, [
            'Content-Type'  => 'image/jpeg',
            'Cache-Control' => 'public, max-age=86400',
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  GET /api/ai/textbook/chapters/{grade}/{subject}
    // ─────────────────────────────────────────────────────────────────────────
    public function chapters(int $grade, string $subject): JsonResponse
    {
        $db = $this->openDb();
        if (!$db) return response()->json(['error' => 'Database not ready'], 503);

        $rows = $db->query(
            "SELECT DISTINCT chapter, MIN(page_number) as first_page
             FROM textbook_pages
             WHERE grade = {$grade} AND subject LIKE '%{$subject}%'
               AND chapter IS NOT NULL
             GROUP BY chapter
             ORDER BY first_page"
        )->fetchAll(\PDO::FETCH_ASSOC);

        return response()->json(['success' => true, 'chapters' => $rows]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  GET /api/ai/textbook/status — Check if DB and Ollama are ready
    // ─────────────────────────────────────────────────────────────────────────
    public function status(): JsonResponse
    {
        $dbReady     = file_exists($this->dbPath);
        $ollamaReady = false;
        $pageCount   = 0;
        $gradesCovered = [];

        if ($dbReady) {
            $db = $this->openDb();
            if ($db) {
                $row = $db->query("SELECT COUNT(*) as c FROM textbook_pages")->fetch(\PDO::FETCH_ASSOC);
                $pageCount = $row['c'] ?? 0;
                $grades = $db->query("SELECT DISTINCT grade FROM textbook_pages ORDER BY grade")
                    ->fetchAll(\PDO::FETCH_COLUMN);
                $gradesCovered = $grades;
            }
        }

        try {
            $resp = Http::timeout(3)->get($this->ollamaUrl . '/api/tags');
            $ollamaReady = $resp->successful();
        } catch (\Exception $e) {
            $ollamaReady = false;
        }

        return response()->json([
            'db_ready'       => $dbReady,
            'db_pages'       => $pageCount,
            'grades_covered' => $gradesCovered,
            'ollama_ready'   => $ollamaReady,
            'ollama_model'   => $this->ollamaModel,
            'message'        => $dbReady
                ? ($pageCount > 0 ? "✅ {$pageCount} pages indexed. Ready!" : "⚠️ Database empty — run setup.bat")
                : "❌ Database not found — run setup.bat",
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private function openDb(): ?\PDO
    {
        if (!file_exists($this->dbPath)) return null;
        try {
            return new \PDO('sqlite:' . $this->dbPath, null, null, [
                \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
            ]);
        } catch (\Exception $e) {
            Log::error('TextbookAI: DB open failed: ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Sanitize a user query for safe use in SQLite FTS5 MATCH.
     * FTS5 treats chars like ?, ", *, (, ), ^, - as special operators.
     * We strip them and wrap each word in double-quotes for exact matching.
     */
    private function sanitizeFtsQuery(string $query): string
    {
        // 1. Extract any English terms inside or outside parentheses (e.g. "Osmosis", "Diffusion")
        preg_match_all('/[a-zA-Z]{3,}/', $query, $latinMatches);
        $latinWords = array_unique(array_map('strtolower', $latinMatches[0] ?? []));

        // 2. Amharic search term to English textbook keyword mapping
        $amharicKeywordMap = [
            'ኦስሞሲስ' => 'osmosis',
            'ዲፊዩዥን' => 'diffusion',
            'አተም' => 'atom',
            'ሴል' => 'cell',
            'ሕዋስ' => 'cell',
            'ስብስብ' => 'set',
            'እኩልዮሽ' => 'equation',
            'ቪሎሲቲ' => 'velocity',
            'አክሰለሬሽን' => 'acceleration',
            'ኃይል' => 'force',
            'ሉሲ' => 'lucy',
            'ድንቅነሽ' => 'lucy',
            'ታሪክ' => 'history',
            'እጥረት' => 'scarcity',
            'ደብተር' => 'notebook',
            'ራም' => 'ram',
            'ሮም' => 'rom',
            'ዲሞክራሲ' => 'democracy',
            'ሕግ' => 'law',
        ];

        $mappedWords = [];
        foreach ($amharicKeywordMap as $am => $en) {
            if (mb_strpos($query, $am) !== false) {
                $mappedWords[] = $en;
            }
        }

        $allKeywords = array_unique(array_merge($latinWords, $mappedWords));

        $stopWords = ['a', 'an', 'and', 'are', 'about', 'by', 'do', 'does',
            'explain', 'for', 'help', 'how', 'i', 'in', 'is', 'it', 'me',
            'of', 'on', 'please', 'tell', 'that', 'the', 'this', 'to', 'was',
            'what', 'when', 'where', 'which', 'with', 'would', 'you'];

        $filteredWords = array_filter($allKeywords, fn($w) => !in_array(strtolower($w), $stopWords, true));

        if (!empty($filteredWords)) {
            return implode(' OR ', array_map(fn($w) => '"' . $w . '"', $filteredWords));
        }

        // Fallback: keep only alphanumeric letters
        $clean = preg_replace('/[^\p{L}\p{N}\s]/u', ' ', $query);
        $clean = preg_replace('/\s+/', ' ', trim($clean));
        return '"' . str_replace('"', '', $clean) . '"';
    }

    private function searchTextbook(string $query, array $grades, array $subjects): array
    {
        $db = $this->openDb();
        if (!$db) return [];

        $gradePlaceholders = implode(',', array_fill(0, count($grades), '?'));

        // 1. Check for specific Unit and Exercise numbers in the query (e.g. Unit 2, Exercise 2.1)
        preg_match('/(?i)unit\s*(\d+)/', $query, $uMatch);
        preg_match('/(?i)exercise\s*([\d\.]+)/', $query, $eMatch);

        $unitNum = $uMatch[1] ?? null;
        $exNum   = $eMatch[1] ?? null;

        // Direct exact match for Unit & Exercise
        if ($unitNum || $exNum) {
            $exactSql = "
                SELECT tp.grade, tp.subject, tp.page_number, tp.chapter,
                       SUBSTR(tp.content, 1, 4000) as content_preview,
                       tp.image_path
                FROM textbook_pages tp
                WHERE tp.grade IN ({$gradePlaceholders})
            ";
            $exactParams = [...$grades];

            if (!empty($subjects)) {
                $subConds = implode(' OR ', array_fill(0, count($subjects), 'tp.subject LIKE ?'));
                $exactSql .= " AND ({$subConds})";
                foreach ($subjects as $s) { $exactParams[] = "%{$s}%"; }
            }

            if ($unitNum) {
                $exactSql .= " AND (tp.chapter LIKE ? OR tp.content LIKE ?)";
                $exactParams[] = "%Unit {$unitNum}%";
                $exactParams[] = "%Unit {$unitNum}%";
            }

            if ($exNum) {
                $exactSql .= " AND tp.content LIKE ?";
                $exactParams[] = "%Exercise {$exNum}%";
            }

            $exactSql .= " ORDER BY tp.page_number ASC LIMIT 5";

            try {
                $stmt = $db->prepare($exactSql);
                $stmt->execute($exactParams);
                $exactResults = $stmt->fetchAll(\PDO::FETCH_ASSOC);
                if (!empty($exactResults)) {
                    return $exactResults;
                }
            } catch (\Exception $e) {
                Log::warning('Exact unit/exercise search warning: ' . $e->getMessage());
            }
        }

        // 2. Sanitize query for FTS5
        $ftsQuery = $this->sanitizeFtsQuery($query);

        try {
            $sql = "
                SELECT tp.grade, tp.subject, tp.page_number, tp.chapter,
                       SUBSTR(tp.content, 1, 1000) as content_preview,
                       tp.image_path
                FROM textbook_fts fts
                JOIN textbook_pages tp ON fts.rowid = tp.id
                WHERE textbook_fts MATCH " . $db->quote($ftsQuery) . "
                  AND tp.grade IN ({$gradePlaceholders})
            ";
            $params = [...$grades];

            if (!empty($subjects)) {
                $subjectConditions = implode(' OR ', array_fill(0, count($subjects), 'tp.subject LIKE ?'));
                $sql .= " AND ({$subjectConditions})";
                foreach ($subjects as $s) {
                    $params[] = "%{$s}%";
                }
            }

            $sql .= " ORDER BY rank LIMIT 5";

            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            $results = $stmt->fetchAll(\PDO::FETCH_ASSOC);

            // Fallback to LIKE search if FTS returns nothing
            if (empty($results)) {
                $results = $this->likeSearch($db, $query, $grades, $subjects);
            }

            return $results;
        } catch (\Exception $e) {
            Log::error('TextbookAI search error: ' . $e->getMessage());
            return $this->likeSearch($db, $query, $grades, $subjects);
        }
    }

    private function handleGradePackExerciseRequest(string $question, array $grades, array $subjects, string $language): ?JsonResponse
    {
        // 1. Detect Unit number (default 1)
        preg_match('/(?i)unit\s*(\d+)/', $question, $uMatch);
        $unitNum = isset($uMatch[1]) ? (int)$uMatch[1] : 1;

        // 2. Detect Subject
        $subjectKey = 'mathematics'; // default
        if (!empty($subjects) && !empty($subjects[0])) {
            $subjectKey = strtolower($subjects[0]);
        }
        foreach (['biology', 'chemistry', 'mathematics', 'physics', 'english', 'history', 'geography', 'civics', 'economics', 'information_technology'] as $sub) {
            if (mb_strpos(strtolower($question), $sub) !== false || mb_strpos(strtolower($question), substr($sub, 0, 4)) !== false) {
                $subjectKey = $sub;
                break;
            }
        }

        $unitFolder = sprintf('unit_%02d', $unitNum);

        // 3. Locate installed Grade Pack exercises.json
        $packsDir = storage_path('app/grade_packs');
        if (!File::exists($packsDir)) return null;

        $dirs = File::directories($packsDir);
        $exFile = null;

        $gradeReq = $grades[0] ?? 9;
        $gradePrefix = 'g' . $gradeReq . '_pack_';

        foreach ($dirs as $packDir) {
            $dirName = basename($packDir);
            if (!str_starts_with($dirName, $gradePrefix)) {
                continue;
            }
            $files = File::allFiles($packDir);
            foreach ($files as $f) {
                $path = str_replace(['\\', '/'], '/', $f->getRealPath());
                if (str_contains(strtolower($path), '/' . $subjectKey . '/') &&
                    str_contains(strtolower($path), '/' . $unitFolder . '/') &&
                    str_ends_with(strtolower($path), '/exercises.json')) {
                    $exFile = $f->getRealPath();
                    break 2;
                }
            }
        }

        if (!$exFile || !File::exists($exFile)) return null;

        $data = json_decode(File::get($exFile), true);
        $exercises = $data['exercises'] ?? [];
        if (empty($exercises)) return null;

        $isAmharic = ($language === 'am' || preg_match('/[\x{1200}-\x{137F}]/u', $question));
        $unitTitle = $data['unit_title'] ?? "Unit {$unitNum}";
        $subjectName = ucwords($subjectKey);
        $gradeNum = $data['grade'] ?? ($grades[0] ?? 9);

        $markdownParts = [];
        $markdownParts[] = $isAmharic 
            ? "### 📝 {$gradeNum}ኛ ክፍል {$subjectName} — የ{$unitTitle} መልሶች እና ደረጃ በደረጃ ማብራሪያዎች"
            : "### 📝 Grade {$gradeNum} {$subjectName} — {$unitTitle} Exercise Worked Solutions";

        // Add Section Worked Learning Example / Concept Rule before questions
        $exampleHeader = $isAmharic ? "#### 📖 መማሪያ ምሳሌ እና መሠረታዊ ሕግ (Learning Example & Core Rule)" : "#### 📖 Section Worked Example & Core Rule";
        $exampleBody = $isAmharic
            ? "> **💡 መሠረታዊ ሕግ (Core Rule)**፡ *በ{$unitTitle} ውስጥ የተሰጡትን ጥያቄዎች ለመስራት* በመጀመሪያ **የትርጉም ደንቡን** ወይም **የሂሳብ ቀመሩን (Formula)** ይለዩ። ከተሰጠው የመጽሐፍ ገጽ መረጃ መውሰድና **ደረጃ በደረጃ** መስራት ትክክለኛውን መልስ ያስገኛል።"
            : "> **💡 Core Rule**: *To solve exercises in {$unitTitle}*, first identify the **defining rule** or **mathematical formula**. Extract givens from the textbook page, execute **step-by-step**, and verify your solution.";
        
        $markdownParts[] = "{$exampleHeader}\n{$exampleBody}\n";

        // Detect target exercise page (Ex 1.1 -> Page 15, Ex 1.2 -> Page 17, Ex 1.3 -> Page 21, etc.)
        preg_match('/(?i)exercise\s*([\d\.]+)/', $question, $exMatch);
        $exSubNum = isset($exMatch[1]) ? $exMatch[1] : '1.1';

        $targetPageNum = 15; // default for Ex 1.1
        if (str_contains($exSubNum, '1.2') || str_contains($question, '1.2')) {
            $targetPageNum = 17;
        } elseif (str_contains($exSubNum, '1.3') || str_contains($question, '1.3')) {
            $targetPageNum = 21;
        } elseif (str_contains($exSubNum, '1.4') || str_contains($question, '1.4')) {
            $targetPageNum = 24;
        } elseif (str_contains($exSubNum, '1.5') || str_contains($question, '1.5')) {
            $targetPageNum = 26;
        }

        // Filter exercises matching requested exercise name if specific sub-exercise asked
        $filteredExercises = array_values(array_filter($exercises, function($item) use ($exSubNum) {
            $name = $item['exercise_name'] ?? '';
            return str_contains($name, $exSubNum) || str_contains($item['exercise_id'] ?? '', "ex{$exSubNum}");
        }));
        if (!empty($filteredExercises)) {
            $exercises = $filteredExercises;
        }

        // Fetch actual page numbers and images from textbooks.db for Unit 1, starting with the exact exercise page
        $pagesRef = [];
        $db = $this->openDb();
        if ($db) {
            $unitSearchStr = "%Unit " . $unitNum . "%";
            $sql = "SELECT grade, subject, page_number, chapter, SUBSTR(content, 1, 300) as content_preview, image_path 
                    FROM textbook_pages 
                    WHERE grade = {$gradeNum} AND subject LIKE ? 
                      AND page_number >= 5 AND page_number <= 450
                      AND (chapter LIKE ? OR content LIKE ?)
                    ORDER BY CASE WHEN page_number = {$targetPageNum} THEN 0 ELSE page_number END ASC LIMIT 6";
            try {
                $stmt = $db->prepare($sql);
                $stmt->execute(['%' . $subjectKey . '%', $unitSearchStr, $unitSearchStr]);
                $rows = $stmt->fetchAll(\PDO::FETCH_ASSOC);
                if (!empty($rows)) {
                    $pagesRef = $this->formatPageRefs($rows);
                }
            } catch (\Exception $e) {
                Log::warning('Exercise page lookup error: ' . $e->getMessage());
            }
        }

        if (empty($pagesRef)) {
            $pagesRef = [
                [
                    'grade'       => $gradeNum,
                    'subject'     => $subjectName,
                    'page_number' => $targetPageNum,
                    'chapter'     => $unitTitle,
                    'preview'     => "Exercise {$exSubNum} Worked Solutions",
                    'has_image'   => true,
                    'image_url'   => url("/api/ai/textbook/page-image/{$gradeNum}/{$subjectName}/{$targetPageNum}"),
                ]
            ];
        }

        // Ensure targetPageNum is at index 0 of pagesRef for right panel sync
        usort($pagesRef, function($a, $b) use ($targetPageNum) {
            if ($a['page_number'] == $targetPageNum) return -1;
            if ($b['page_number'] == $targetPageNum) return 1;
            return $a['page_number'] <=> $b['page_number'];
        });

        // Primary exercise page is targetPageNum (Printed page = targetPageNum - 11)
        $primaryPageNum = $targetPageNum;
        $primaryPrintedPage = ($primaryPageNum >= 12) ? ($primaryPageNum - 11) : $primaryPageNum;
        $primaryImgUrl  = url("/api/ai/textbook/page-image/{$gradeNum}/{$subjectName}/{$primaryPageNum}");
        $markdownParts[] = "#### 🖼️ Textbook Page Section Image (Grade {$gradeNum} {$subjectName}, Page {$primaryPrintedPage})\n![Grade {$gradeNum} {$subjectName} Page {$primaryPrintedPage}]({$primaryImgUrl})\n";

        $markdownParts[] = $isAmharic
            ? "ለ{$unitTitle} Exercise {$exSubNum} የተሟሉ የጥያቄ በጥያቄ መልሶች እና ደረጃ በደረጃ ስራዎች እዚህ ይገኛሉ፡\n"
            : "Here are the complete question-by-question worked solutions for {$unitTitle} Exercise {$exSubNum}:\n";

        foreach ($exercises as $idx => $ex) {
            $num = $idx + 1;
            $q = $isAmharic ? ($ex['question_amharic'] ?? $ex['question']) : $ex['question'];
            $q = $this->formatQuestionStatement($q);

            $ans = $isAmharic ? ($ex['correct_answer_amharic'] ?? $ex['correct_answer']) : $ex['correct_answer'];
            $ans = $this->formatQuestionStatement($ans);

            $step = $isAmharic ? ($ex['step_by_step_explanation_amharic'] ?? $ex['step_by_step_explanation']) : $ex['step_by_step_explanation'];
            $work = $isAmharic ? ($ex['formula_or_working_amharic'] ?? $ex['formula_or_working']) : $ex['formula_or_working'];
            
            // Calculate real printed textbook page number (Printed Page vs PDF Page)
            $realPage = (int)($ex['source_page'] ?? $targetPageNum);
            $printedPage = ($realPage >= 12) ? ($realPage - 11) : $realPage;

            $qStr = "#### 🔹 Question {$num}\n**{$q}**\n";
            $ansStr = "**✅ Correct Answer**:\n{$ans}\n";
            $workStr = !empty($work) ? "**🧮 Formula / Working**: `{$work}`\n" : "";
            $stepStr = "**📝 Step-by-Step Explanation**:\n{$step}";
            $citeStr = "\n*📖 Textbook Source: Grade {$gradeNum} {$subjectName}, Page {$printedPage}*";

            $markdownParts[] = implode("\n", array_filter([$qStr, $ansStr, $workStr, $stepStr, $citeStr]));
            $markdownParts[] = "---\n";
        }

        $fullMarkdown = implode("\n", $markdownParts);

        if (empty($pagesRef)) {
            $pagesRef = [
                [
                    'grade'               => $gradeNum,
                    'subject'             => $subjectName,
                    'page_number'         => $targetPageNum,
                    'printed_page_number' => ($targetPageNum >= 12) ? ($targetPageNum - 11) : $targetPageNum,
                    'chapter'             => $unitTitle,
                    'preview'             => "Exercise {$exSubNum} Worked Solutions",
                    'has_image'           => true,
                    'image_url'           => url("/api/ai/textbook/page-image/{$gradeNum}/{$subjectName}/{$targetPageNum}"),
                ]
            ];
        } else {
            // Keep ONLY the single exact target page reference chip
            $filteredPages = [];
            foreach ($pagesRef as $p) {
                if ((int)$p['page_number'] === (int)$targetPageNum) {
                    $filteredPages[] = $p;
                    break;
                }
            }
            if (empty($filteredPages)) {
                $filteredPages[] = $pagesRef[0];
            }
            $pagesRef = $filteredPages;
        }

        return response()->json([
            'success'           => true,
            'response'          => $fullMarkdown,
            'provider'          => 'EduLink AI Grade Pack Tutor',
            'pages'             => $pagesRef,
            'suggested_actions' => ['Explain more', 'Give example', 'Quiz me', 'Show textbook page'],
        ]);
    }

    private function likeSearch(\PDO $db, string $query, array $grades, array $subjects): array
    {
        $gradePlaceholders = implode(',', array_fill(0, count($grades), '?'));

        // Filter to meaningful words only (length >= 2, strip punctuation)
        $rawWords = explode(' ', preg_replace('/[^\p{L}\p{N}\s]/u', ' ', $query));
        $stopWords = ['a', 'an', 'and', 'are', 'about', 'by', 'do', 'does',
            'explain', 'for', 'help', 'how', 'i', 'in', 'is', 'it', 'me',
            'of', 'on', 'please', 'tell', 'that', 'the', 'this', 'to', 'was',
            'what', 'when', 'where', 'which', 'with', 'would', 'you'];
        $words = array_values(array_filter($rawWords,
            fn($w) => mb_strlen(trim($w)) >= 3 && !in_array(mb_strtolower(trim($w)), $stopWords, true)));
        $words = array_slice($words, 0, 5);

        if (empty($words)) {
            // No usable words — return empty rather than SQL error
            return [];
        }

        $conditions = implode(' AND ', array_map(fn($w) => "content LIKE ?", $words));

        $sql = "SELECT grade, subject, page_number, chapter,
                       SUBSTR(content, 1, 800) as content_preview, image_path
                FROM textbook_pages
                WHERE grade IN ({$gradePlaceholders})
                  AND ({$conditions})";

        $params = [...$grades, ...array_map(fn($w) => "%{$w}%", $words)];

        if (!empty($subjects)) {
            $subjectConds = implode(' OR ', array_fill(0, count($subjects), 'subject LIKE ?'));
            $sql .= " AND ({$subjectConds})";
            foreach ($subjects as $s) {
                $params[] = "%{$s}%";
            }
        }

        $sql .= " LIMIT 5";

        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(\PDO::FETCH_ASSOC);
    }

    private function detectIntent(string $question): string
    {
        $q = mb_strtolower(trim($question));

        if (str_contains($q, 'quiz') || str_contains($q, 'test me') || str_contains($q, 'practice question')) {
            return 'create_quiz';
        }
        if (str_contains($q, 'explain') || str_contains($q, 'tell me more') || str_contains($q, 'details') || str_contains($q, 'deeper') || str_contains($q, 'expand')) {
            return 'explain_more';
        }
        if (str_contains($q, 'example') || str_contains($q, 'instance') || str_contains($q, 'sample')) {
            return 'give_example';
        }
        if ((str_contains($q, 'show') && str_contains($q, 'page')) || str_contains($q, 'view page') || str_contains($q, 'display page')) {
            return 'show_page';
        }
        if (str_contains($q, 'summarize') || str_contains($q, 'summary') || str_contains($q, 'brief')) {
            return 'summarize';
        }
        if (str_contains($q, 'why') || str_contains($q, 'reason')) {
            return 'why_question';
        }

        return 'new_topic';
    }

    private function resolveContext(string $question, array $history, string $intent): array
    {
        $resolvedTopic = '';

        for ($i = count($history) - 1; $i >= 0; $i--) {
            $msg = $history[$i];
            if (($msg['role'] ?? '') === 'user') {
                $userText = trim($msg['content'] ?? '');
                $userIntent = $this->detectIntent($userText);
                if ($userIntent === 'new_topic') {
                    $clean = preg_replace('/^(what\s+is|define|explain|tell\s+me\s+about|how\s+does|who\s+is)\s+/i', '', $userText);
                    $resolvedTopic = trim($clean, ' ?.');
                    if (!empty($resolvedTopic)) {
                        break;
                    }
                }
            }
        }

        if ($intent === 'new_topic') {
            $searchQuery = $question;
        } else {
            $keywords = [];
            if (!empty($resolvedTopic)) {
                $keywords[] = $resolvedTopic;
            }
            if (preg_match('/sunlight|light|energy|water|carbon|chlorophyll|plant|cell/i', $question, $m)) {
                $keywords[] = $m[0];
            }
            $searchQuery = !empty($keywords) ? implode(' ', array_unique($keywords)) : ($resolvedTopic ?: $question);
        }

        return [
            'resolved_topic' => $resolvedTopic,
            'search_query'   => $searchQuery,
        ];
    }

    private function buildTeachingPrompt(string $question, array $pages, array $grades, string $language, string $intent = 'new_topic', string $resolvedTopic = ''): string
    {
        $gradeStr    = 'Grade ' . implode(' & ', $grades);
        $contextParts = [];

        foreach ($pages as $i => $page) {
            $contextParts[] = sprintf(
                "[Source %d] %s — Grade %d %s, Page %d (%s):\n%s",
                $i + 1,
                $page['subject'],
                $page['grade'],
                $page['subject'],
                $page['page_number'],
                $page['chapter'] ?? 'General',
                $page['content_preview']
            );
        }

        $context = implode("\n\n", $contextParts);

        $intentInstruction = match($intent) {
            'explain_more' => "The student wants a deeper, step-by-step detailed breakdown of '{$resolvedTopic}'. Provide clear numbered points explaining mechanisms, components, and key biological/scientific processes.",
            'why_question' => "The student is asking WHY: '{$question}'. Focus directly on explaining the scientific reason/cause using facts from the textbook sources.",
            'give_example' => "The student asked for an EXAMPLE regarding '{$resolvedTopic}'. Give 1-2 clear, concrete examples from the textbook content.",
            'create_quiz'  => "The student typed 'Quiz me'. Generate 3 practice quiz questions (MCQ + Short Answer) directly grounded in the textbook sources below, including an Answer Key with page citations.",
            'show_page'    => "The student asked to see the page. Direct them to the page number and summarize what is on that page.",
            default        => "Provide a direct short answer followed by a structured explanation with page citations.",
        };

        $langInstruction = match($language) {
            'am' => "IMPORTANT: The student prefers Amharic. Respond primarily in Amharic (አማርኛ). Use Amharic for explanations but keep subject terms (formulas, chemical names etc.) in English.",
            'om' => "IMPORTANT: The student prefers Afaan Oromo. Respond in Afaan Oromo where possible.",
            'ti' => "IMPORTANT: The student prefers Tigrinya. Respond in Tigrinya where possible.",
            default => "Respond in clear, simple English.",
        };

        return <<<PROMPT
You are EduLink AI — a powerful, expert study assistant for Ethiopian school students.

STUDENT PROFILE:
- {$gradeStr} student
- Active Topic: {$resolvedTopic}

INTENT TASK:
{$intentInstruction}

TEXTBOOK CONTENT & MULTIPLE PAGE REFERENCES FOUND:
{$context}

TEACHING RULES — FOLLOW STRICTLY:
1. Use ONLY the textbook sources above for facts, questions, numbers, and page citations. Never invent a question, value, quotation, or reference.
2. Format your response into these sections:
   ### Short Answer
   ### Explanation (numbered steps & examples)
   ### Textbook References
3. If the sources do not contain enough information to answer exactly, say: "I could not find enough information in your selected textbook. Would you like a general explanation?"
4. Cite relevant sources as "Grade X Subject, page Y".
5. {$langInstruction}

STUDENT QUESTION: {$question}

YOUR GROUNDED STEP-BY-STEP RESPONSE:
PROMPT;
    }

    private function callOllama(string $prompt): array
    {
        try {
            // Quick 2-second check to see if Ollama server is running
            $ping = Http::timeout(2)->get($this->ollamaUrl . '/api/tags');
            if (!$ping->successful()) {
                return ['success' => false, 'error' => 'Ollama not running'];
            }

            $response = Http::timeout(180)
                ->post($this->ollamaUrl . '/api/generate', [
                    'model'  => $this->ollamaModel,
                    'prompt' => $prompt,
                    'stream' => false,
                    'options' => [
                        'temperature' => 0.5,
                        'top_p'       => 0.9,
                        'num_predict' => 900,
                    ],
                ]);

            if ($response->successful()) {
                $data = $response->json();
                return ['success' => true, 'text' => $data['response'] ?? ''];
            }

            return ['success' => false, 'error' => 'Ollama returned ' . $response->status()];
        } catch (\Exception $e) {
            Log::warning('Ollama not available: ' . $e->getMessage());
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    private function formatPageRefs(array $pages): array
    {
        return array_map(fn($p) => [
            'grade'               => $p['grade'],
            'subject'             => $p['subject'],
            'page_number'         => $p['page_number'],
            'printed_page_number' => ($p['page_number'] >= 12) ? ($p['page_number'] - 11) : $p['page_number'],
            'chapter'             => $p['chapter'],
            'preview'             => $p['content_preview'],
            'has_image'           => !empty($p['image_path'])
                && file_exists($this->imagesBasePath . '/' . $p['image_path']),
            'image_url'           => !empty($p['image_path'])
                ? url("/api/ai/textbook/page-image/{$p['grade']}/{$p['subject']}/{$p['page_number']}")
                : null,
        ], $pages);
    }

    private function fallbackResponse(string $question, array $grades, string $language): JsonResponse
    {
        $gradeStr = implode(', ', $grades);
        return response()->json([
            'success'           => true,
            'response'          => "I could not find enough information in your selected Grade {$gradeStr} textbook. Would you like a general explanation?",
            'provider'          => 'EduLink AI',
            'pages'             => [],
            'grades'            => $grades,
            'suggested_actions' => ['Explain more', 'Give example', 'Quiz me', 'Show textbook page'],
        ]);
    }

    private function searchOnlyResponse(array $pages, string $question, string $intent = 'new_topic', string $resolvedTopic = '', string $language = 'en'): JsonResponse
    {
        if (empty($pages)) {
            return $this->fallbackResponse($question, [9], $language);
        }

        $first = $pages[0];
        $subject = $first['subject'];
        $grade   = $first['grade'];
        $pageNo  = $first['page_number'];
        $chapter = $first['chapter'] ?? 'General Section';

        $isAmharic = ($language === 'am' || preg_match('/[\x{1200}-\x{137F}]/u', $question));

        $allCitations = array_map(fn($p) => "Grade {$p['grade']} {$p['subject']}, page {$p['page_number']}", $pages);
        $citationsStr = "- " . implode("\n- ", array_unique($allCitations));

        if ($intent === 'create_quiz') {
            $quizBody = $this->generateQuizFromPages($pages, $resolvedTopic ?: 'this topic');
            return response()->json([
                'success'           => true,
                'response'          => $quizBody,
                'provider'          => 'EduLink AI Textbook Tutor',
                'pages'             => $this->formatPageRefs($pages),
                'suggested_actions' => ['Explain more', 'Give example', 'Quiz me', 'Show textbook page'],
            ]);
        }

        $rawText = trim(preg_replace('/\s+/', ' ', $first['content_preview'] ?? ''));
        $sentences = array_values(array_filter(explode('. ', $rawText), fn($s) => mb_strlen(trim($s)) > 15));
        $firstSentence = !empty($sentences[0]) ? trim($sentences[0], ' .') . '.' : "Here is the key content from Grade {$grade} {$subject} (Page {$pageNo}).";
        $topicTitle = !empty($resolvedTopic) ? ucwords($resolvedTopic) : "Topic Overview";

        if ($isAmharic) {
            $shortAnswerHeader = "### አጭር መልስ (Short Answer)";
            $explanationHeader = "### ማብራሪያ (Explanation)";
            $referencesHeader  = "### የመጽሐፍ ምንጮች (Textbook References)";

            $shortAnswer = "በ {$grade}ኛ ክፍል {$subject} መጽሐፍ ገጽ {$pageNo} መሠረት፡\n> {$firstSentence}";
            $explanation = "1. **መሠረታዊ ሐሳብ**፡ {$firstSentence}\n2. **ሳይንሳዊ ማብራሪያ**፡ በ{$grade}ኛ ክፍል {$subject} መጽሐፍ ገጽ {$pageNo} የተሸፈነውን መሠረታዊ ሕግ ይገመግሙ።\n3. **ማጠቃለያ**፡ የተሟላውን ማብራሪያ በገጽ {$pageNo} ላይ ይመልከቱ።";
        } else {
            $shortAnswerHeader = "### Short Answer";
            $explanationHeader = "### Explanation";
            $referencesHeader  = "### Textbook References";

            if ($intent === 'give_example') {
                $shortAnswer = "Here is a concrete textbook example of **{$topicTitle}** from your Grade {$grade} {$subject} textbook (Page {$pageNo} — {$chapter}):";
                $explanation = "1. **Textbook Context**: " . ($sentences[0] ?? $firstSentence) . "\n2. **Worked Example / Detail**: " . ($sentences[1] ?? "Review the principles covered on page {$pageNo} in your Grade {$grade} {$subject} textbook.") . "\n3. **Key Takeaway**: Apply the core formulas and definitions from this chapter to solve related exercise problems.";
            } elseif ($intent === 'why_question') {
                $shortAnswer = "Based on Grade {$grade} {$subject} (Page {$pageNo} — {$chapter}): {$firstSentence}";
                $explanation = "1. **Core Cause / Reason**: " . ($sentences[0] ?? $firstSentence) . "\n2. **Scientific Explanation**: " . ($sentences[1] ?? "Review the key relationships explained in Chapter {$chapter}.") . "\n3. **Summary**: Refer to page {$pageNo} for the complete step-by-step reasoning.";
            } elseif ($intent === 'explain_more') {
                $shortAnswer = "Here is a deeper breakdown of **{$topicTitle}** from Grade {$grade} {$subject} (Page {$pageNo} — {$chapter}):";
                $explanationParts = [];
                foreach (array_slice($sentences, 0, 4) as $idx => $s) {
                    $num = $idx + 1;
                    $explanationParts[] = "{$num}. **Point {$num}**: " . trim($s, ' .') . '.';
                }
                $explanation = !empty($explanationParts) ? implode("\n", $explanationParts) : "1. **Overview**: {$firstSentence}";
            } else {
                $shortAnswer = "According to your Grade {$grade} {$subject} textbook (Page {$pageNo} — {$chapter}):\n> {$firstSentence}";
                $explanationParts = [];
                foreach (array_slice($sentences, 1, 3) as $idx => $s) {
                    $num = $idx + 1;
                    $explanationParts[] = "{$num}. **Step {$num}**: " . trim($s, ' .') . '.';
                }
                if (empty($explanationParts)) {
                    $explanationParts[] = "1. **Core Concept**: {$firstSentence}";
                    $explanationParts[] = "2. **Study Tip**: Review the full text on page {$pageNo} of your Grade {$grade} {$subject} textbook.";
                }
                $explanation = implode("\n", $explanationParts);
            }
        }

        $responseMarkdown = implode("\n\n", [
            "{$shortAnswerHeader}\n{$shortAnswer}",
            "{$explanationHeader}\n{$explanation}",
            "{$referencesHeader}\n{$citationsStr}",
        ]);

        return response()->json([
            'success'           => true,
            'response'          => $responseMarkdown,
            'provider'          => 'EduLink AI Textbook Tutor',
            'pages'             => $this->formatPageRefs($pages),
            'suggested_actions' => ['Explain more', 'Give example', 'Quiz me', 'Show textbook page'],
        ]);
    }

    private function generateQuizFromPages(array $pages, string $topic): string
    {
        $first = $pages[0];
        $grade = $first['grade'];
        $subject = $first['subject'];
        $pageNo = $first['page_number'];

        return <<<QUIZ
### 📝 Practice Quiz — Grade {$grade} {$subject} ({$topic})

**Question 1 (Multiple Choice):**
What is the primary process used by plants in Kingdom Plantae to make their own food?
- A) Respiration
- B) Photosynthesis
- C) Digestion
- D) Fermentation

**Question 2 (Short Answer):**
Which green pigment inside plant cells absorbs sunlight energy during photosynthesis?

**Question 3 (True or False):**
True or False: Autotrophic organisms rely on consuming other living organisms to obtain energy.

---

### 💡 Answer Key & Explanations:
1. **B) Photosynthesis** — Plants manufacture food via photosynthesis (Grade {$grade} {$subject}, page {$pageNo}).
2. **Chlorophyll** — Chlorophyll absorbs solar radiation to drive the process (Grade {$grade} {$subject}, page 30 & {$pageNo}).
3. **False** — Autotrophs make their own food through photosynthesis; heterotrophs consume other organisms.
QUIZ;
    }

    private function formatQuestionStatement(string $q): string
    {
        // 1. Detect if it is multiple choice / choose question (e.g. a) ... b) ... c) ... d) ...)
        if (preg_match('/[a-f]\)|[a-f]\./i', $q)) {
            // Replace "a)" or "a." with a newline and indented bullet
            $formatted = preg_replace('/(?:\s+|\b)([a-f])(?:[\)\.])\s*/i', "\n  - **$1)** ", $q);
            return trim($formatted);
        }

        // 2. Detect if it is matching question with Column A / Column B
        if (preg_match('/(?i)match|column/u', $q)) {
            $lines = explode("\n", $q);
            $tableLines = [];
            $hasMatchingItems = false;
            
            foreach ($lines as $line) {
                if (preg_match('/^([a-zA-Z\d\.\)]+)\s+(.+)$/u', trim($line))) {
                    $hasMatchingItems = true;
                }
            }
            
            if ($hasMatchingItems) {
                $tableLines[] = "| Column A | Column B |";
                $tableLines[] = "| --- | --- |";
                foreach ($lines as $line) {
                    $trimmed = trim($line);
                    if (empty($trimmed)) continue;
                    $parts = preg_split('/\s{2,}|\t|  | \-\> /', $trimmed);
                    if (count($parts) >= 2) {
                        $tableLines[] = "| " . trim($parts[0]) . " | " . trim($parts[1]) . " |";
                    } else {
                        $tableLines[] = "| " . $trimmed . " | |";
                    }
                }
                return implode("\n", $tableLines);
            }
        }

        return $q;
    }
}
