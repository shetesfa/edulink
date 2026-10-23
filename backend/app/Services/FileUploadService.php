<?php

namespace App\Services;

use App\Models\FileUpload;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;

class FileUploadService
{
    private const ALLOWED_EXTENSIONS = [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx',
        'jpg', 'jpeg', 'png', 'gif', 'webp',
        'mp4', 'mov', 'mp3', 'wav', 'ogg',
        'txt', 'zip',
    ];

    private const MAX_SIZE_BYTES = 50 * 1024 * 1024; // 50 MB

    /**
     * Store an uploaded file safely and record its metadata.
     *
     * @throws \InvalidArgumentException if the file type/size is not allowed
     */
    public function store(UploadedFile $file, int $uploaderId, string $relatedType, ?int $relatedId, bool $isPublic = false): FileUpload
    {
        $extension = strtolower($file->getClientOriginalExtension());

        if (!in_array($extension, self::ALLOWED_EXTENSIONS)) {
            throw new \InvalidArgumentException("File type .{$extension} is not allowed.");
        }

        if ($file->getSize() > self::MAX_SIZE_BYTES) {
            throw new \InvalidArgumentException('File exceeds the 50MB size limit.');
        }

        // Sanitize: never trust the original filename, generate our own
        $storedName = Str::uuid() . '.' . $extension;
        $disk = $isPublic ? 'public' : 'local';
        $folder = "uploads/{$relatedType}s";

        $path = $file->storeAs($folder, $storedName, $disk);

        return FileUpload::create([
            'uploader_id' => $uploaderId,
            'related_type' => $relatedType,
            'related_id' => $relatedId,
            'original_name' => $file->getClientOriginalName(),
            'stored_name' => $storedName,
            'file_path' => $path,
            'file_type' => $file->getClientMimeType(),
            'file_size' => $file->getSize(),
            'is_public' => $isPublic,
        ]);
    }
}
