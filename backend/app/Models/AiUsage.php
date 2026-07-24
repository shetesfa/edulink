<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class AiUsage extends Model {
  protected $fillable=['provider','user_id','tokens_used','request_count','date'];
  protected $casts=['date'=>'date'];
  public function user() { return $this->belongsTo(User::class); }
}
