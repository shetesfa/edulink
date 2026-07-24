<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Classes extends Model {
  protected $table='classes';
  protected $fillable=['school_id','grade_id','teacher_id','name','subject','description','cover_photo','color','join_code','invite_link','is_active','max_students','allow_student_chat'];
  public function school()       { return $this->belongsTo(School::class); }
  public function grade()        { return $this->belongsTo(Grade::class); }
  public function teacher()      { return $this->belongsTo(User::class,'teacher_id'); }
  public function enrollments()  { return $this->hasMany(Enrollment::class,'class_id'); }
  public function lessons()      { return $this->hasMany(Lesson::class,'class_id'); }
  public function assignments()  { return $this->hasMany(Assignment::class,'class_id'); }
  public function quizzes()      { return $this->hasMany(Quiz::class,'class_id'); }
  public function announcements(){ return $this->hasMany(Announcement::class,'class_id'); }
  public function groupChat()    { return $this->hasOne(GroupChat::class,'class_id'); }
}
