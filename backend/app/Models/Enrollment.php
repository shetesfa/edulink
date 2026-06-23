<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Enrollment extends Model {
  public $timestamps=false;
  protected $fillable=['class_id','student_id','is_class_leader','is_banned','progress_percent'];
  protected $attributes=['joined_at'=>null];
  protected $casts=['joined_at'=>'datetime'];
  public function student() { return $this->belongsTo(User::class,'student_id'); }
  public function class()   { return $this->belongsTo(Classes::class,'class_id'); }
}
