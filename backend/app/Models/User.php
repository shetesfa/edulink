<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Support\Carbon;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'school_id', 'role_id', 'first_name', 'last_name', 'username',
        'email', 'password', 'google_id', 'profile_photo', 'cover_photo',
        'bio', 'grade', 'phone', 'date_of_birth', 'gender', 'is_active',
    ];

    protected $hidden = [
        'password', 'remember_token', 'otp_code_hash',
        'password_reset_token_hash',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
        'is_active' => 'boolean',
        'is_online' => 'boolean',
        'date_of_birth' => 'date',
        'last_seen' => 'datetime',
        'otp_expires_at' => 'datetime',
        'otp_last_sent_at' => 'datetime',
        'password_reset_expires_at' => 'datetime',
    ];

    // --- Relationships ---
    public function school()
    {
        return $this->belongsTo(School::class);
    }

    public function role()
    {
        return $this->belongsTo(Role::class);
    }

    public function settings()
    {
        return $this->hasOne(UserSetting::class);
    }

    public function classesTaught()
    {
        return $this->hasMany(SchoolClass::class, 'teacher_id');
    }

    public function enrollments()
    {
        return $this->hasMany(Enrollment::class, 'student_id');
    }

    public function enrolledClasses()
    {
        return $this->belongsToMany(SchoolClass::class, 'enrollments', 'student_id', 'class_id')
            ->withPivot(['is_class_leader', 'is_banned', 'progress_percent', 'joined_at'])
            ->withTimestamps();
    }

    public function quizAttempts()
    {
        return $this->hasMany(QuizAttempt::class, 'student_id');
    }

    public function assignmentSubmissions()
    {
        return $this->hasMany(AssignmentSubmission::class, 'student_id');
    }

    // --- Helpers ---
    public function fullName(): string
    {
        return trim("{$this->first_name} {$this->last_name}");
    }

    public function hasRole(string $roleName): bool
    {
        return $this->role && strtolower($this->role->name) === strtolower($roleName);
    }

    /**
     * Generate a 6-digit OTP, store only its HASH + expiry, and return the
     * PLAIN code so the caller can email/sms it. Plain code is never persisted.
     */
    public function generateOtp(int $expiresInMinutes = 10): string
    {
        $plainOtp = (string) random_int(100000, 999999);

        $this->otp_code_hash = Hash::make($plainOtp);
        $this->otp_expires_at = Carbon::now()->addMinutes($expiresInMinutes);
        $this->otp_last_sent_at = Carbon::now();
        $this->otp_attempts = 0;
        $this->save();

        return $plainOtp;
    }

    public function canResendOtp(int $cooldownSeconds = 60): bool
    {
        if (!$this->otp_last_sent_at) {
            return true;
        }
        return Carbon::now()->diffInSeconds($this->otp_last_sent_at) >= $cooldownSeconds;
    }

    public function verifyOtp(string $plainOtp): bool
    {
        if (!$this->otp_code_hash || !$this->otp_expires_at) {
            return false;
        }

        if (Carbon::now()->greaterThan($this->otp_expires_at)) {
            return false;
        }

        if ($this->otp_attempts >= 5) {
            return false; // too many wrong tries, must request a new OTP
        }

        $matches = Hash::check($plainOtp, $this->otp_code_hash);

        if (!$matches) {
            $this->increment('otp_attempts');
            return false;
        }

        // success - clear the OTP so it cannot be reused
        $this->otp_code_hash = null;
        $this->otp_expires_at = null;
        $this->otp_attempts = 0;
        $this->save();

        return true;
    }

    /**
     * Generate a password reset token, store only its hash, return the plain
     * token to be emailed as a link/code.
     */
    public function generatePasswordResetToken(int $expiresInMinutes = 30): string
    {
        $plainToken = Str::random(6) . '-' . random_int(1000, 9999);

        $this->password_reset_token_hash = Hash::make($plainToken);
        $this->password_reset_expires_at = Carbon::now()->addMinutes($expiresInMinutes);
        $this->save();

        return $plainToken;
    }

    public function verifyPasswordResetToken(string $plainToken): bool
    {
        if (!$this->password_reset_token_hash || !$this->password_reset_expires_at) {
            return false;
        }
        if (Carbon::now()->greaterThan($this->password_reset_expires_at)) {
            return false;
        }
        return Hash::check($plainToken, $this->password_reset_token_hash);
    }

    public function clearPasswordResetToken(): void
    {
        $this->password_reset_token_hash = null;
        $this->password_reset_expires_at = null;
        $this->save();
    }
}
