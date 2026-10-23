<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// Table is "files" - named FileUpload in code to avoid confusion with PHP's
// built-in SplFileInfo/File-related classes.
class FileUpload extends Model
{
    protected $table = 'files';

    protected $fillable = [
        'uploader_id', 'related_type', 'related_id', 'original_name',
        'stored_name', 'file_path', 'file_type', 'file_size', 'is_public',
    ];

    protected $casts = [
        'is_public' => 'boolean',
    ];

    public function uploader()
    {
        return $this->belongsTo(User::class, 'uploader_id');
    }
}
