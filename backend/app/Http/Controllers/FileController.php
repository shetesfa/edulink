<?php

namespace App\Http\Controllers;

use App\Models\File;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;

// ─────────────────────────────────────────────────────────────
// FileController
// ─────────────────────────────────────────────────────────────
class FileController extends Controller
{
    public function upload(Request $request): JsonResponse
    {
        $request->validate([
            'file'         => 'required|file|max:102400',
            'related_type' => 'nullable|string|max:50',
            'related_id'   => 'nullable|integer',
        ]);

        $user         = $request->user();
        $uploadedFile = $request->file('file');
        $originalName = $uploadedFile->getClientOriginalName();
        $storedName   = time().'_'.preg_replace('/[^a-zA-Z0-9._-]/', '_', $originalName);
        $folder       = $request->related_type ? $request->related_type.'s' : 'uploads';
        $path         = $uploadedFile->storeAs("{$folder}/{$user->id}", $storedName, 'public');

        $file = File::create([
            'uploader_id'   => $user->id,
            'related_type'  => $request->related_type,
            'related_id'    => $request->related_id,
            'original_name' => $originalName,
            'stored_name'   => $storedName,
            'file_path'     => $path,
            'file_type'     => $uploadedFile->getMimeType(),
            'file_size'     => $uploadedFile->getSize(),
        ]);

        return response()->json([
            'success' => true,
            'file'    => [
                'id'   => $file->id,
                'name' => $file->original_name,
                'url'  => Storage::disk('public')->url($path),
                'type' => $file->file_type,
                'size' => $file->file_size,
            ],
        ], 201);
    }

    public function download(Request $request, int $id): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        $file = File::findOrFail($id);
        $file->increment('download_count');
        return Storage::disk('public')->download($file->file_path, $file->original_name);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $file = File::findOrFail($id);
        if ($file->uploader_id !== $request->user()->id && $request->user()->role->name !== 'school_admin') {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 403);
        }
        Storage::disk('public')->delete($file->file_path);
        $file->delete();
        return response()->json(['success' => true]);
    }
}
