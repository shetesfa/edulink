<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class GroupChatMember extends Model {
  public $timestamps=false;
  protected $fillable=['group_id','user_id','role','is_muted'];
  protected $casts=['joined_at'=>'datetime','last_read_at'=>'datetime'];
  public function user()  { return $this->belongsTo(User::class); }
  public function group() { return $this->belongsTo(GroupChat::class); }
}
