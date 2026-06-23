<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class LessonComment extends Model {
  protected $fillable=['lesson_id','user_id','parent_id','body'];
  public function user()    { return $this->belongsTo(User::class); }
  public function lesson()  { return $this->belongsTo(Lesson::class); }
  public function replies() { return $this->hasMany(LessonComment::class,'parent_id'); }
}
