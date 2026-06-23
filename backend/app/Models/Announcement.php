<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Announcement extends Model {
  protected $fillable=['class_id','author_id','title','body','is_pinned'];
  public function class()  { return $this->belongsTo(Classes::class,'class_id'); }
  public function author() { return $this->belongsTo(User::class,'author_id'); }
}
