<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Message extends Model {
  protected $fillable=['sender_id','receiver_id','group_id','reply_to_id','forwarded_from_id','message_type','body','is_edited','is_deleted','is_pinned','reactions','metadata'];
  protected $casts=['is_edited'=>'boolean','is_deleted'=>'boolean','is_pinned'=>'boolean'];
  public function sender()   { return $this->belongsTo(User::class,'sender_id'); }
  public function receiver() { return $this->belongsTo(User::class,'receiver_id'); }
  public function group()    { return $this->belongsTo(GroupChat::class,'group_id'); }
  public function replyTo()  { return $this->belongsTo(Message::class,'reply_to_id'); }
  public function files()    { return $this->hasMany(File::class,'related_id')->where('related_type','message'); }
}
