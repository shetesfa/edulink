<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class File extends Model {
  public $timestamps=false;
  protected $fillable=['uploader_id','related_type','related_id','original_name','stored_name','file_path','file_type','file_size','is_public','download_count'];
  protected $casts=['created_at'=>'datetime'];
  public function uploader() { return $this->belongsTo(User::class,'uploader_id'); }
}
