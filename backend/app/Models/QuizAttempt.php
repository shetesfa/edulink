<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class QuizAttempt extends Model {
  public $timestamps=false;
  protected $fillable=['quiz_id','student_id','answers','score','max_score','percentage','passed','time_taken_seconds','started_at','submitted_at'];
  protected $casts=['started_at'=>'datetime','submitted_at'=>'datetime','passed'=>'boolean'];
  public function student() { return $this->belongsTo(User::class,'student_id'); }
  public function quiz()    { return $this->belongsTo(Quiz::class); }
}
