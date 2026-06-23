<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Quiz extends Model {
  protected $fillable=['class_id','teacher_id','title','description','time_limit_minutes','max_attempts','shuffle_questions','show_answers_after','pass_score','is_published','opens_at','closes_at'];
  protected $casts=['opens_at'=>'datetime','closes_at'=>'datetime'];
  public function class()     { return $this->belongsTo(Classes::class,'class_id'); }
  public function teacher()   { return $this->belongsTo(User::class,'teacher_id'); }
  public function questions() { return $this->hasMany(QuizQuestion::class); }
  public function attempts()  { return $this->hasMany(QuizAttempt::class); }
}
