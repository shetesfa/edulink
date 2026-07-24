<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class GroupChat extends Model {
  protected $fillable=['name','description','avatar','type','class_id','created_by','invite_link','join_code','is_public'];
  public function class()       { return $this->belongsTo(Classes::class,'class_id'); }
  public function creator()     { return $this->belongsTo(User::class,'created_by'); }
  public function members()     { return $this->belongsToMany(User::class,'group_chat_members','group_id','user_id')->withPivot('role','joined_at','last_read_at','is_muted'); }
  public function messages()    { return $this->hasMany(Message::class,'group_id'); }
  public function lastMessage() { return $this->hasOne(Message::class,'group_id')->latestOfMany(); }
}
