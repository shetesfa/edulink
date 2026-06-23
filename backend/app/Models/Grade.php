<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
class Grade extends Model {
  public $timestamps=false;
  protected $fillable=['school_id','name','order_index'];
  public function school()  { return $this->belongsTo(School::class); }
  public function classes() { return $this->hasMany(Classes::class); }
}
