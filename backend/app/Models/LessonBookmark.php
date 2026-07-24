<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class LessonBookmark extends Model {
  public $timestamps=false;
  protected $fillable=['lesson_id','user_id'];
  protected $casts=['created_at'=>'datetime'];
}
