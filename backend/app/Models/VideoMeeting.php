<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class VideoMeeting extends Model {
  protected $fillable=['class_id','host_id','title','room_id','scheduled_at','started_at','ended_at','status','is_recorded','recording_url','participant_count'];
  protected $casts=['scheduled_at'=>'datetime','started_at'=>'datetime','ended_at'=>'datetime'];
  public function class() { return $this->belongsTo(Classes::class,'class_id'); }
  public function host()  { return $this->belongsTo(User::class,'host_id'); }
}
