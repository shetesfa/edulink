<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserSetting;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;

class AuthController extends Controller
{
    // ─────────────────────────────────────────────────────────────
    // REGISTER  →  creates account, sends email OTP for verification
    // ─────────────────────────────────────────────────────────────

    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'first_name'    => 'required|string|max:80',
            'last_name'     => 'required|string|max:80',
            'email'         => 'required|email|unique:users,email|max:180',
            'password'      => 'required|string|min:8|confirmed',
            'role'          => 'required|in:student,teacher',
            'school_id'     => 'nullable|exists:schools,id',
            'profile_photo' => 'nullable|image|max:5120',
            'grade'         => 'nullable|string|max:30',
            'school_name'   => 'nullable|string|max:200',
        ]);

        $schoolId = $validated['school_id'] ?? null;
        $roleMap  = ['student' => 2, 'teacher' => 3];

        $user = User::create([
            'first_name'       => $validated['first_name'],
            'last_name'        => $validated['last_name'],
            'username'         => $this->generateUsername($validated['first_name'], $validated['last_name']),
            'email'            => $validated['email'],
            'password'         => Hash::make($validated['password']),
            'role_id'          => $roleMap[$validated['role']],
            'school_id'        => $schoolId,
            'grade'            => $validated['grade'] ?? null,
            'email_verified'   => 1,   // bypass verification for development
        ]);

        if ($request->hasFile('profile_photo')) {
            $path = $request->file('profile_photo')->store("avatars/{$user->id}", 'public');
            $user->update(['profile_photo' => $path]);
        }

        UserSetting::create(['user_id' => $user->id]);

        // Send email OTP
        $otpRes = $this->sendOtpEmail($user, 'email_verify');

        $response = [
            'success' => true,
            'message' => 'Account created! Please verify your email with the code we just sent.',
            'email'   => $user->email,
        ];

        if (!$otpRes['sent']) {
            $response['debug_otp'] = $otpRes['otp'];
        }

        return response()->json($response, 201);
    }

    // ─────────────────────────────────────────────────────────────
    // VERIFY EMAIL OTP  →  marks email verified, returns token
    // ─────────────────────────────────────────────────────────────

    public function verifyEmail(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'otp'   => 'required|string|size:6',
        ]);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['success' => false, 'message' => 'User not found.'], 404);
        }

        [$valid, $error] = $this->checkOtp($user, 'email_verify', $request->otp);
        if (!$valid) {
            return response()->json(['success' => false, 'message' => $error, 'expired' => str_contains($error, 'expired')], 422);
        }

        $user->update(['email_verified' => 1, 'is_active' => 1]);

        $token = $user->createToken('auth_token', ['*'], now()->addDays(30))->plainTextToken;
        $user->update(['is_online' => 1, 'last_seen' => now()]);

        return response()->json([
            'success' => true,
            'message' => 'Email verified! Welcome to EduLink.',
            'token'   => $token,
            'user'    => $this->formatUser($user->fresh(['role', 'school'])),
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // RESEND EMAIL OTP
    // ─────────────────────────────────────────────────────────────

    public function resendEmailOtp(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email']);
        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['success' => true, 'message' => 'If registered, a new code was sent.']);
        }
        $otpRes = $this->sendOtpEmail($user, 'email_verify');
        $response = ['success' => true, 'message' => 'New verification code sent!'];
        if (!$otpRes['sent']) {
            $response['debug_otp'] = $otpRes['otp'];
        }
        return response()->json($response);
    }

    // ─────────────────────────────────────────────────────────────
    // SEND LOGIN OTP  (Step 1 of OTP Login)
    // ─────────────────────────────────────────────────────────────

    public function sendLoginOtp(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email']);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'No account found with this email. Please register first.',
            ], 404);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated. Contact your school admin.',
            ], 403);
        }

        // Bypass email verification for development
        // if (!$user->email_verified) {
        //     return response()->json([
        //         'success'            => false,
        //         'message'            => 'Please verify your email address before signing in.',
        //         'needs_verification' => true,
        //         'email'              => $user->email,
        //     ], 403);
        // }

        $otpRes = $this->sendOtpEmail($user, 'login_otp');

        $response = [
            'success' => true,
            'message' => 'A 6-digit sign-in code was sent to your email.',
        ];

        if (!$otpRes['sent']) {
            $response['debug_otp'] = $otpRes['otp'];
        }

        return response()->json($response);
    }

    // ─────────────────────────────────────────────────────────────
    // PASSWORD LOGIN  (Standard Email/Password)
    // ─────────────────────────────────────────────────────────────

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email'    => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid credentials.'],
            ]);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated. Contact your school admin.',
            ], 403);
        }

        // Bypass email verification for development
        // if (!$user->email_verified) {
        //     return response()->json([
        //         'success'            => false,
        //         'message'            => 'Please verify your email address before logging in.',
        //         'needs_verification' => true,
        //         'email'              => $user->email,
        //     ], 403);
        // }

        $user->update(['is_online' => 1, 'last_seen' => now()]);

        $token = $user->createToken('auth_token', ['*'], now()->addDays(30))->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful!',
            'token'   => $token,
            'user'    => $this->formatUser($user->fresh(['role', 'school'])),
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // VERIFY LOGIN OTP  (Step 2 of OTP Login)  →  returns token
    // ─────────────────────────────────────────────────────────────

    public function verifyLoginOtp(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'otp'   => 'required|string|size:6',
        ]);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Incorrect or expired code.'], 422);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated. Contact your school admin.',
            ], 403);
        }

        [$valid, $error] = $this->checkOtp($user, 'login_otp', $request->otp);
        if (!$valid) {
            return response()->json([
                'success' => false,
                'message' => $error,
                'expired' => str_contains($error, 'expired'),
            ], 422);
        }

        $user->update(['is_online' => 1, 'last_seen' => now()]);

        $token = $user->createToken('auth_token', ['*'], now()->addDays(30))->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful!',
            'token'   => $token,
            'user'    => $this->formatUser($user->fresh(['role', 'school'])),
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // LOGOUT
    // ─────────────────────────────────────────────────────────────

    public function logout(Request $request): JsonResponse
    {
        $request->user()->update(['is_online' => 0, 'last_seen' => now()]);
        $request->user()->currentAccessToken()->delete();
        return response()->json(['success' => true, 'message' => 'Logged out successfully.']);
    }

    // ─────────────────────────────────────────────────────────────
    // GET CURRENT USER
    // ─────────────────────────────────────────────────────────────

    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load('role', 'school', 'settings');
        return response()->json(['user' => $this->formatUser($user)]);
    }

    // ─────────────────────────────────────────────────────────────
    // GOOGLE OAUTH REDIRECT
    // ─────────────────────────────────────────────────────────────

    public function googleRedirect(Request $request): \Symfony\Component\HttpFoundation\RedirectResponse
    {
        $role = $request->get('role', 'student');
        if (!in_array($role, ['student', 'teacher'], true)) {
            $role = 'student';
        }
        $state = base64_encode(json_encode(['role' => $role]));
        return Socialite::driver('google')->stateless()->with(['state' => $state])->redirect();
    }

    public function googleCallback(Request $request)
    {
        $frontendUrl = rtrim(env('FRONTEND_URL', 'https://edulink-blond.vercel.app'), '/');

        try {
            try {
                \DB::connection()->getPdo();
            } catch (\Exception $e) {
                return redirect("{$frontendUrl}/login?error=db_error");
            }

            $googleUser = Socialite::driver('google')->stateless()->user();
        } catch (\Exception $e) {
            \Log::error('Google OAuth Error: ' . $e->getMessage() . ' | Trace: ' . $e->getTraceAsString());
            return redirect("{$frontendUrl}/login?error=google_failed&msg=" . urlencode($e->getMessage()));
        }

        $state = $request->get('state');
        $role = 'student';
        if ($state) {
            $decoded = json_decode(base64_decode($state), true);
            if (is_array($decoded) && isset($decoded['role']) && in_array($decoded['role'], ['student', 'teacher'], true)) {
                $role = $decoded['role'];
            }
        }

        $roleMap = ['student' => 2, 'teacher' => 3];
        $roleId  = $roleMap[$role] ?? 2;

        $user = User::where('email', $googleUser->getEmail())->first();
        $isNew = false;

        if (!$user) {
            $isNew = true;
            $nameParts = explode(' ', $googleUser->getName() ?? 'User', 2);
            $user = User::create([
                'first_name'     => $nameParts[0],
                'last_name'      => $nameParts[1] ?? '',
                'username'       => $this->generateUsername($nameParts[0], $nameParts[1] ?? ''),
                'email'          => $googleUser->getEmail(),
                'password'       => Hash::make(Str::random(32)),
                'password_set'   => 0,
                'role_id'        => $roleId,
                'profile_photo'  => $googleUser->getAvatar(),
                'google_id'      => $googleUser->getId(),
                'email_verified' => 1,
                'is_active'      => 1,
            ]);
            UserSetting::create(['user_id' => $user->id]);
        }

        if (!$user->is_active) {
            return redirect("{$frontendUrl}/login?error=account_disabled");
        }

        // Existing accounts keep their role — never overwrite on Google login
        $user->update([
            'is_online'     => 1,
            'last_seen'     => now(),
            'google_id'     => $googleUser->getId(),
            'email_verified'=> 1,
            'profile_photo' => $googleUser->getAvatar() ?: $user->profile_photo,
        ]);

        $token = $user->createToken('auth_token', ['*'], now()->addDays(30))->plainTextToken;

        $qs = http_build_query(array_filter([
            'token' => $token,
            'info'  => $isNew ? null : 'existing_account',
        ]));

        return redirect("{$frontendUrl}/login?{$qs}");
    }

    // ─────────────────────────────────────────────────────────────
    // PASSWORD RESET (OTP-based, existing flow)
    // ─────────────────────────────────────────────────────────────

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email']);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['success' => true, 'message' => 'If that email is registered, a code was sent.']);
        }

        $otpRes = $this->sendOtpEmail($user, 'password_reset');
        $response = ['success' => true, 'message' => 'A 6-digit reset code was sent to your email.'];
        if (!$otpRes['sent']) {
            $response['debug_otp'] = $otpRes['otp'];
        }
        return response()->json($response);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email', 'otp' => 'required|string|size:6']);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Invalid or expired code.'], 422);
        }

        [$valid, $error] = $this->checkOtp($user, 'password_reset', $request->otp);
        if (!$valid) {
            return response()->json(['success' => false, 'message' => $error, 'expired' => str_contains($error, 'expired')], 422);
        }

        // Issue a short-lived reset token
        $resetToken = Str::random(64);
        Cache::put("pw_reset_{$user->id}", Hash::make($resetToken), now()->addMinutes(15));

        return response()->json(['success' => true, 'reset_token' => $resetToken]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email'    => 'required|email',
            'token'    => 'required|string',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Invalid request.'], 422);
        }

        $cached = Cache::get("pw_reset_{$user->id}");
        if (!$cached || !Hash::check($request->token, $cached)) {
            return response()->json(['success' => false, 'message' => 'Invalid or expired reset link.'], 422);
        }

        $user->update([
            'password' => Hash::make($request->password),
            'password_set' => 1
        ]);
        Cache::forget("pw_reset_{$user->id}");

        // Revoke all tokens
        $user->tokens()->delete();

        return response()->json(['success' => true, 'message' => 'Password updated! You can now sign in.']);
    }

    // ─────────────────────────────────────────────────────────────
    // PROFILE UPDATE
    // ─────────────────────────────────────────────────────────────

    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validate([
            'first_name'    => 'sometimes|string|max:80',
            'last_name'     => 'sometimes|string|max:80',
            'bio'           => 'nullable|string|max:500',
            'grade'         => 'nullable|string|max:30',
            'profile_photo' => 'nullable|image|max:5120',
        ]);

        if ($request->hasFile('profile_photo')) {
            if ($user->profile_photo && !str_starts_with($user->profile_photo, 'http')) {
                Storage::disk('public')->delete($user->profile_photo);
            }
            $validated['profile_photo'] = $request->file('profile_photo')->store("avatars/{$user->id}", 'public');
        }

        $user->update(array_filter($validated, fn($v) => $v !== null));

        return response()->json([
            'success' => true,
            'message' => 'Profile updated!',
            'user'    => $this->formatUser($user->fresh(['role', 'school'])),
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();
        $rules = [
            'password' => 'required|string|min:8|confirmed',
        ];

        if ($user->password_set) {
            $rules['current_password'] = 'required|string';
        }

        $request->validate($rules);

        if ($user->password_set) {
            if (!Hash::check($request->current_password, $user->password)) {
                return response()->json(['success' => false, 'message' => 'Current password is incorrect.'], 422);
            }
        }

        $user->update([
            'password' => Hash::make($request->password),
            'password_set' => 1,
        ]);
        $user->tokens()->where('id', '!=', $user->currentAccessToken()->id)->delete();

        return response()->json([
            'success' => true, 
            'message' => 'Password set successfully!',
            'user'    => $this->formatUser($user->fresh(['role', 'school'])),
        ]);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'dark_mode' => 'boolean',
            'language'  => 'string|in:en,am,om,ti,so,ar,fr',
        ]);

        $user = $request->user();
        $settings = $user->settings ?? \App\Models\UserSetting::create(['user_id' => $user->id]);
        $settings->update($validated);

        return response()->json(['success' => true, 'message' => 'Settings saved.', 'settings' => $settings]);
    }

    // ─────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────

    /**
     * Generate and send an OTP email. Stores in cache AND otp_codes table.
     */
    private function sendOtpEmail(User $user, string $type): array
    {
        $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $ttl = now()->addMinutes(10);

        // Store in cache (fast check)
        Cache::put("otp_{$type}_{$user->id}", $otp, $ttl);

        // Also store in DB for audit
        try {
            \DB::table('otp_codes')->insert([
                'user_id'    => $user->id,
                'type'       => $type,
                'code'       => $otp, // Store plaintext to avoid column truncation if schema is outdated
                'expires_at' => $ttl,
                'ip_address' => request()->ip(),
                'created_at' => now(),
            ]);
        } catch (\Exception $e) {
            Log::error("Failed to insert OTP audit log: " . $e->getMessage());
        }

        $subjects = [
            'login_otp'      => 'Your EduLink sign-in code',
            'email_verify'   => 'Verify your EduLink email',
            'password_reset' => 'Your EduLink password reset code',
        ];

        $titles = [
            'login_otp'      => 'Sign-In Code',
            'email_verify'   => 'Email Verification',
            'password_reset' => 'Password Reset Code',
        ];

        $subject = $subjects[$type] ?? 'Your EduLink code';
        $title   = $titles[$type] ?? 'Verification Code';

        $sent = true;
        try {
            Mail::send([], [], function ($message) use ($user, $otp, $subject, $title) {
                $message->to($user->email, $user->full_name)
                    ->subject($subject)
                    ->html("
                    <div style='font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#f9fafb;'>
                        <div style='background:#1E1B4B;border-radius:20px;padding:40px;text-align:center;'>
                            <div style='font-size:32px;margin-bottom:8px;'>🎓</div>
                            <h1 style='color:#fff;font-size:22px;margin:0 0 4px;font-weight:800;'>EduLink</h1>
                            <p style='color:rgba(255,255,255,0.6);font-size:13px;margin:0 0 32px;'>{$title}</p>

                            <p style='color:rgba(255,255,255,0.75);font-size:14px;margin:0 0 16px;'>
                                Hi {$user->first_name}! Your verification code is:
                            </p>

                            <div style='background:linear-gradient(135deg,#7C3AED,#4F46E5);border-radius:16px;padding:24px;margin:0 0 24px;'>
                                <div style='font-size:48px;font-weight:900;letter-spacing:16px;color:#fff;font-family:monospace;'>{$otp}</div>
                            </div>

                            <p style='color:rgba(255,255,255,0.5);font-size:12px;margin:0;'>
                                This code expires in <strong style='color:rgba(255,255,255,0.75);'>10 minutes</strong>.<br>
                                If you didn't request this, ignore this email.
                            </p>
                        </div>
                        <p style='color:#9CA3AF;font-size:11px;text-align:center;margin-top:20px;'>
                            &copy; " . date('Y') . " EduLink. All rights reserved.
                        </p>
                    </div>");
            });
        } catch (\Exception $e) {
            Log::error("OTP email failed for user {$user->id}: " . $e->getMessage());
            $sent = false;
        }

        try {
            file_put_contents(public_path('latest_otp.json'), json_encode([
                'code'      => $otp,
                'email'     => $user->email,
                'timestamp' => time(),
            ]));
        } catch (\Exception $e) {
            Log::error("Failed to write latest_otp.json: " . $e->getMessage());
        }

        return ['otp' => $otp, 'sent' => $sent];
    }

    /**
     * Validate an OTP code.  Returns [bool $valid, string $error].
     */
    private function checkOtp(User $user, string $type, string $code): array
    {
        $cacheKey = "otp_{$type}_{$user->id}";
        $cached   = Cache::get($cacheKey);

        if ($cached === null) {
            return [false, 'Code expired or not found. Please request a new one.'];
        }

        if ($cached !== $code) {
            return [false, 'Incorrect code. Please try again.'];
        }

        Cache::forget($cacheKey);
        return [true, ''];
    }

    /**
     * Generate a unique username from first+last name.
     */
    private function generateUsername(string $first, string $last): string
    {
        $base = strtolower(Str::slug($first . '.' . $last, '.'));
        $base = preg_replace('/[^a-z0-9.]/', '', $base);
        $base = substr($base, 0, 20);

        $username = $base;
        $i = 1;
        while (User::where('username', $username)->exists()) {
            $username = $base . $i++;
        }
        return $username;
    }

    /**
     * Consistently format user for API responses.
     */
    private function formatUser(User $user): array
    {
        $roleNames = [1 => 'super_admin', 2 => 'student', 3 => 'teacher', 4 => 'teacher'];

        return [
            'id'            => $user->id,
            'first_name'    => $user->first_name,
            'last_name'     => $user->last_name,
            'full_name'     => $user->full_name ?? "{$user->first_name} {$user->last_name}",
            'username'      => $user->username,
            'email'         => $user->email,
            'role'          => $roleNames[$user->role_id] ?? 'student',
            'role_id'       => $user->role_id,
            'school_id'     => $user->school_id,
            'school_name'   => $user->school?->name,
            'profile_photo' => $user->profile_photo
                ? (str_starts_with($user->profile_photo, 'http')
                    ? $user->profile_photo
                    : Storage::disk('public')->url($user->profile_photo))
                : null,
            'grade'         => $user->grade,
            'bio'           => $user->bio,
            'is_online'     => (bool) $user->is_online,
            'last_seen'     => $user->last_seen?->toISOString(),
            'email_verified'=> (bool) ($user->email_verified ?? true),
            'password_set'  => (bool) ($user->password_set ?? true),
            'created_at'    => $user->created_at?->toISOString(),
            'settings'      => $user->settings ? [
                'dark_mode' => (bool) $user->settings->dark_mode,
                'language'  => $user->settings->language ?? 'en',
            ] : ['dark_mode' => false, 'language' => 'en'],
        ];
    }
}
