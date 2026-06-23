<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class AssignmentSubmission extends Model {
  public $timestamps=false;
  protected $fillable=['assignment_id','student_id','text_answer','score','feedback','status','submitted_at','graded_at'];
  protected $casts=['submitted_at'=>'datetime','graded_at'=>'datetime'];
  public function student()    { return $this->belongsTo(User::class,'student_id'); }
  public function assignment() { return $this->belongsTo(Assignment::class); }
  public function files()      { return $this->hasMany(File::class,'related_id')->where('related_type','submission'); }
}
