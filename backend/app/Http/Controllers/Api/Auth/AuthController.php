<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\SendOtpRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Models\User;
use App\Models\UserSetting;
use App\Models\Role;
use App\Notifications\OtpNotification;
use App\Notifications\WelcomeNotification;
use App\Notifications\PasswordResetNotification;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    /**
     * POST /api/auth/register
     */
    public function register(RegisterRequest $request)
    {
        $data = $request->validated();

        $user = User::create([
            'first_name' => $data['first_name'],
            'last_name'  => $data['last_name'],
            'email'      => $data['email'],
            'username'   => $data['username'] ?? $this->generateUsername($data['email']),
            'password'   => Hash::make($data['password']),
            'phone'      => $data['phone'] ?? null,
            'school_id'  => $data['school_id'] ?? null,
            'role_id'    => Role::STUDENT,
        ]);

        UserSetting::create(['user_id' => $user->id]);

        $otp = $user->generateOtp();
        
        // Send single verification code email
        try {
            $user->notify(new OtpNotification($otp, 'verify_email'));
        } catch (\Throwable $e) {
            \Log::warning("Email send failed for {$user->email}, OTP is {$otp}: " . $e->getMessage());
        }

        \Log::info("OTP generated for {$user->email}: {$otp}");

        return response()->json([
            'success' => true,
            'message' => 'Account created. A 6-digit verification code has been sent to your email.',
            'data' => [
                'email' => $user->email,
            ],
        ], 201);
    }

    /** POST /api/auth/resend-verification-otp */
    public function resendVerificationOtp(SendOtpRequest $request)
    {
        $user = User::where('email', $request->email)->firstOrFail();

        if ($user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'This email is already verified.'], 422);
        }

        $otp = $user->generateOtp();
        \Log::info("Resent OTP for {$user->email}: {$otp}");

        try {
            $user->notify(new OtpNotification($otp, 'verify_email'));
        } catch (\Throwable $e) {
            \Log::warning("Email send failed for {$user->email}, OTP is {$otp}: " . $e->getMessage());
        }

        return response()->json([
            'success' => true,
            'message' => 'A new verification code has been sent to your email.',
            'data' => [
                'email' => $user->email,
            ],
        ]);
    }

    /**
     * POST /api/auth/verify-email
     */
    public function verifyEmail(VerifyOtpRequest $request)
    {
        $user = User::where('email', $request->email)->firstOrFail();

        if (!$user->verifyOtp($request->otp)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired verification code.',
            ], 422);
        }

        $user->email_verified_at = now();
        $user->save();

        $token = $user->createToken('edulink-mobile')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Email verified successfully.',
            'data' => ['user' => $user->load('role', 'settings'), 'token' => $token],
        ]);
    }

    /**
     * POST /api/auth/login  (email + password)
     */
    public function login(LoginRequest $request)
    {
        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'The provided credentials are incorrect.',
            ], 401);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'This account has been deactivated. Contact your school admin.',
            ], 403);
        }

        if (!$user->email_verified_at) {
            return response()->json([
                'success' => false,
                'message' => 'Please verify your email before logging in.',
                'data' => ['requires_verification' => true],
            ], 403);
        }

        $token = $user->createToken('edulink-mobile')->plainTextToken;
        $user->update(['is_online' => true, 'last_seen' => now()]);

        return response()->json([
            'success' => true,
            'message' => 'Logged in successfully.',
            'data' => ['user' => $user->load('role', 'settings'), 'token' => $token],
        ]);
    }

    /**
     * POST /api/auth/send-login-otp
     */
    public function sendLoginOtp(SendOtpRequest $request)
    {
        $email = strtolower(trim($request->email));
        $user = User::where('email', $email)->first();

        if (!$user) {
            return response()->json(['success' => false, 'message' => 'No account found with this email address.'], 404);
        }

        if (!$user->is_active) {
            return response()->json(['success' => false, 'message' => 'This account has been deactivated. Contact your school admin.'], 403);
        }

        if (!$user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'Please verify your email before requesting a login code.'], 403);
        }

        $otp = $user->generateOtp();
        \Log::info("OTP generated for {$user->email}: {$otp}");

        try {
            $user->notify(new OtpNotification($otp, 'login'));
        } catch (\Throwable $e) {
            \Log::warning("Email send failed for {$user->email}, OTP is {$otp}: " . $e->getMessage());
        }

        return response()->json([
            'success' => true,
            'message' => 'A 6-digit login code has been sent to your email address.',
            'data' => [
                'email' => $user->email,
            ],
        ]);
    }

    /**
     * POST /api/auth/verify-login-otp
     */
    public function verifyLoginOtp(VerifyOtpRequest $request)
    {
        $email = strtolower(trim($request->email));
        $user = User::where('email', $email)->first();

        if (!$user) {
            return response()->json(['success' => false, 'message' => 'No account found with this email address.'], 404);
        }

        if (!$user->is_active) {
            return response()->json(['success' => false, 'message' => 'This account has been deactivated. Contact your school admin.'], 403);
        }

        if (!$user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'Please verify your email before logging in.'], 403);
        }

        if (empty($request->otp) || !$user->verifyOtp((string)$request->otp)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired code.',
            ], 422);
        }

        $user->update(['is_online' => true, 'last_seen' => now()]);

        $token = $user->createToken('edulink-mobile')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Logged in successfully.',
            'data' => ['user' => $user->load('role', 'settings'), 'token' => $token],
        ]);
    }

    /**
     * POST /api/auth/forgot-password
     */
    public function forgotPassword(ForgotPasswordRequest $request)
    {
        $user = User::where('email', $request->email)->firstOrFail();

        $token = $user->generatePasswordResetToken();
        $user->notify(new PasswordResetNotification($token));

        return response()->json([
            'success' => true,
            'message' => 'A password reset code has been sent to your email.',
        ]);
    }

    /**
     * POST /api/auth/reset-password
     */
    public function resetPassword(ResetPasswordRequest $request)
    {
        $user = User::where('email', $request->email)->firstOrFail();

        if (!$user->verifyPasswordResetToken($request->token)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired reset code.',
            ], 422);
        }

        $user->password = Hash::make($request->password);
        $user->clearPasswordResetToken();

        // Revoke all existing tokens for security after a password reset
        $user->tokens()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Password reset successfully. Please log in again.',
        ]);
    }

    /**
     * POST /api/auth/change-password (authenticated)
     */
    public function changePassword(ChangePasswordRequest $request)
    {
        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect.',
            ], 422);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully.',
        ]);
    }

    /**
     * The first-run mobile flow lets a verified user choose student or
     * teacher. Administrative roles can only be assigned by an admin route.
     */
    public function updateRole(Request $request)
    {
        $data = $request->validate([
            'role' => ['required', 'in:student,teacher'],
        ]);

        $roleId = $data['role'] === 'teacher' ? Role::TEACHER : Role::STUDENT;
        $request->user()->update(['role_id' => $roleId]);

        return response()->json([
            'success' => true,
            'message' => 'Role updated successfully.',
            'data' => ['user' => $request->user()->fresh()->load('role', 'settings')],
        ]);
    }

    /**
     * POST /api/auth/logout (authenticated)
     */
    public function logout(Request $request)
    {
        $request->user()->update(['is_online' => false, 'last_seen' => now()]);
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully.',
        ]);
    }

    /**
     * GET /api/auth/me (authenticated)
     */
    public function me(Request $request)
    {
        return response()->json([
            'success' => true,
            'data' => ['user' => $request->user()->load('role', 'settings', 'school')],
        ]);
    }

    /**
     * POST /api/auth/profile (authenticated)
     */
    public function updateProfile(UpdateProfileRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        if ($request->hasFile('profile_photo')) {
            $path = $request->file('profile_photo')->store('profile-photos', 'public');
            $data['profile_photo'] = url('storage/' . $path);
        }

        $user->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Profile updated successfully.',
            'data' => ['user' => $user->fresh()->load('role', 'settings')],
        ]);
    }

    /**
     * PUT /api/settings (authenticated)
     */
    public function updateSettings(Request $request)
    {
        $validated = $request->validate([
            'dark_mode' => ['sometimes', 'boolean'],
            'language' => ['sometimes', 'in:en,am,om,ti,so,ar,fr'],
            'notifications_enabled' => ['sometimes', 'boolean'],
            'email_notifications' => ['sometimes', 'boolean'],
            'sound_enabled' => ['sometimes', 'boolean'],
            'show_online_status' => ['sometimes', 'boolean'],
            'allow_messages_from' => ['sometimes', 'in:everyone,classmates,nobody'],
            'theme' => ['sometimes', 'string', 'max:20'],
            'font_size' => ['sometimes', 'in:small,medium,large'],
        ]);

        $settings = $request->user()->settings ?? UserSetting::create(['user_id' => $request->user()->id]);
        $settings->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Settings updated.',
            'data' => ['settings' => $settings->fresh()],
        ]);
    }

    /**
     * Generate a unique username from an email address.
     */
    private function generateUsername(string $email): string
    {
        $base = preg_replace('/[^a-z0-9]/', '', strtolower(explode('@', $email)[0]));
        $base = substr($base ?: 'user', 0, 20);
        $candidate = $base;
        $i = 2;
        while (User::where('username', $candidate)->exists()) {
            $candidate = $base . $i++;
        }
        return $candidate;
    }
}
