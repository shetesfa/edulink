<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Assignment extends Model {
  protected $fillable=['class_id','teacher_id','title','description','max_score','due_date','allow_late','is_published'];
  protected $casts=['due_date'=>'datetime'];
  public function class()       { return $this->belongsTo(Classes::class,'class_id'); }
  public function teacher()     { return $this->belongsTo(User::class,'teacher_id'); }
  public function submissions() { return $this->hasMany(AssignmentSubmission::class); }
  public function files()       { return $this->hasMany(File::class,'related_id')->where('related_type','assignment'); }
}
