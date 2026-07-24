<?php
namespace App\Models;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable {
  use HasApiTokens, HasFactory;
  protected $fillable = ['school_id','role_id','first_name','last_name','username','email','email_verified_at','password','google_id','profile_photo','cover_photo','bio','grade','phone','date_of_birth','gender','is_active','is_online','last_seen','remember_token','password_reset_token','password_reset_expires'];
  protected $hidden   = ['password','remember_token','password_reset_token'];
  protected $casts    = ['email_verified_at'=>'datetime','last_seen'=>'datetime','password_reset_expires'=>'datetime','is_active'=>'boolean','is_online'=>'boolean'];
  public function role()         { return $this->belongsTo(Role::class); }
  public function school()       { return $this->belongsTo(School::class); }
  public function settings()     { return $this->hasOne(UserSetting::class); }
  public function enrollments()  { return $this->hasMany(Enrollment::class,'student_id'); }
  public function classes()      { return $this->hasMany(Classes::class,'teacher_id'); }
  public function notifications(){ return $this->hasMany(Notification::class); }
  public function getFullNameAttribute(): string { return $this->first_name.' '.$this->last_name; }
}
