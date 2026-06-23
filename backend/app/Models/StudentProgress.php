<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class StudentProgress extends Model {
  public $timestamps=false;
  protected $fillable=['student_id','class_id','lessons_viewed','lessons_total','assignments_submitted','assignments_total','avg_quiz_score','quizzes_taken','last_activity'];
  protected $casts=['last_activity'=>'datetime'];
  public function student() { return $this->belongsTo(User::class,'student_id'); }
  public function class()   { return $this->belongsTo(Classes::class,'class_id'); }
}
