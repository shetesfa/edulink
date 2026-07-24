<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Lesson extends Model {
  protected $fillable=['class_id','teacher_id','title','description','content','order_index','is_published','allow_comments','allow_downloads','views'];
  public function class()    { return $this->belongsTo(Classes::class,'class_id'); }
  public function teacher()  { return $this->belongsTo(User::class,'teacher_id'); }
  public function files()    { return $this->hasMany(File::class,'related_id')->where('related_type','lesson'); }
  public function comments() { return $this->hasMany(LessonComment::class); }
  public function bookmarks(){ return $this->hasMany(LessonBookmark::class); }
}
