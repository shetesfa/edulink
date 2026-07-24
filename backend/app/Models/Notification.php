<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Notification extends Model {
  public $timestamps=false;
  protected $fillable=['user_id','type','title','body','icon','related_type','related_id','action_url','is_read'];
  protected $casts=['created_at'=>'datetime','is_read'=>'boolean'];
  public function user() { return $this->belongsTo(User::class); }
}
