<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class QuizQuestion extends Model {
  public $timestamps=false;
  protected $fillable=['quiz_id','question_type','question_text','options','correct_answer','points','order_index','explanation'];
  public function quiz() { return $this->belongsTo(Quiz::class); }
}
