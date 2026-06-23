<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserSetting;
use App\Models\School;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Laravel\Socialite\Facades\Socialite;

class AuthController extends Controller
{
    // ─────────────────────────────────────────────────────────────
    // REGISTER
    // ─────────────────────────────────────────────────────────────

    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'first_name'      => 'required|string|max:80',
            'last_name'       => 'required|string|max:80',
            'email'           => 'required|email|unique:users,email|max:180',
            'password'        => 'required|string|min:8|confirmed',
            'role'            => 'required|in:student,teacher,school_admin',
            'school_id'       => 'nullable|exists:schools,id',
            'profile_photo'   => 'nullable|image|max:5120', // 5MB
            'grade'           => 'nullable|string|max:30',
            'school_name'     => 'nullable|string|max:200', // if creating new school
        ]);

        // Handle school creation if registering as school admin
        $schoolId = $validated['school_id'] ?? null;
        if ($validated['role'] === 'school_admin' && !$schoolId && !empty($validated['school_name'])) {
            $school = School::create([
                'name'    => $validated['school_name'],
                'slug'    => Str::slug($validated['school_name']) . '-' . Str::random(6),
                'country' => 'Ethiopia',
            ]);
            $schoolId = $school->id;
        }

        // Map role name to role_id
        $roleMap = ['student' => 2, 'teacher' => 3, 'school_admin' => 4];

        $user = User::create([
            'first_name' => $validated['first_name'],
            'last_name'  => $validated['last_name'],
            'username'   => $this->generateUsername($validated['first_name'], $validated['last_name']),
            'email'      => $validated['email'],
            'password'   => Hash::make($validated['password']),
            'role_id'    => $roleMap[$validated['role']],
            'school_id'  => $schoolId,
            'grade'      => $validated['grade'] ?? null,
        ]);

        // Handle profile photo upload
        if ($request->hasFile('profile_photo')) {
            $path = $request->file('profile_photo')->store("avatars/{$user->id}", 'public');
            $user->update(['profile_photo' => $path]);
        }

        // Create default settings
        UserSetting::create(['user_id' => $user->id]);

        // Generate token
        $token = $user->createToken('auth_token')->plainTextToken;

        // Send welcome email (queued)
        // Mail::to($user->email)->queue(new WelcomeMail($user));

        return response()->json([
            'success' => true,
            'message' => 'Account created successfully!',
            'token'   => $token,
            'user'    => $this->formatUser($user),
        ], 201);
    }

    // ─────────────────────────────────────────────────────────────
    // LOGIN
    // ─────────────────────────────────────────────────────────────

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email'       => 'required|email',
            'password'    => 'required|string',
            'remember_me' => 'boolean',
        ]);

        $user = User::where('email', $request->email)->with('role', 'school')->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Your account has been deactivated. Please contact your school admin.',
            ], 403);
        }

        // Update online status
        $user->update(['is_online' => 1, 'last_seen' => now()]);

        // Token expiry: 30 days if remember_me, else 24 hours
        $expiresAt = $request->remember_me
            ? now()->addDays(30)
            : now()->addHours(24);

        $token = $user->createToken('auth_token', ['*'], $expiresAt)->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful!',
            'token'   => $token,
            'expires_at' => $expiresAt->toISOString(),
            'user'    => $this->formatUser($user),
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
    // GOOGLE OAUTH
    // ─────────────────────────────────────────────────────────────

    public function googleRedirect(Request $request): \Symfony\Component\HttpFoundation\RedirectResponse
    {
        $role = $request->query('role', 'student');
        return Socialite::driver('google')
            ->scopes(['openid', 'email', 'profile'])
            ->with(['state' => $role])
            ->redirect();
    }

    public function googleCallback(Request $request): \Symfony\Component\HttpFoundation\Response
    {
        try {
            $googleUser = Socialite::driver('google')->stateless()->user();
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Google authentication failed.'], 401);
        }

        // Get role from state parameter (passed from redirect)
        $requestedRole = $request->input('state', 'student');
        $roleMap = ['student' => 2, 'teacher' => 3, 'school_admin' => 4];
        $roleId = $roleMap[$requestedRole] ?? 2;

        // Find or create user
        $user = User::where('google_id', $googleUser->id)
            ->orWhere('email', $googleUser->email)
            ->first();

        if (!$user) {
            // New user from Google
            $nameParts = explode(' ', $googleUser->name, 2);
            $user = User::create([
                'first_name'        => $nameParts[0] ?? 'User',
                'last_name'         => $nameParts[1] ?? '',
                'username'          => $this->generateUsername($nameParts[0] ?? 'user', $nameParts[1] ?? ''),
                'email'             => $googleUser->email,
                'google_id'         => $googleUser->id,
                'email_verified_at' => now(),
                'password'          => Hash::make(Str::random(32)),
                'profile_photo'     => $googleUser->avatar,
                'role_id'           => $roleId,
                'is_active'         => 1,
            ]);
            UserSetting::create(['user_id' => $user->id]);
        } else {
            $user->update([
                'google_id'         => $googleUser->id,
                'email_verified_at' => $user->email_verified_at ?? now(),
                'is_online'         => 1,
            ]);
        }

        $token = $user->createToken('google_auth_token')->plainTextToken;

        $frontendUrl = env('FRONTEND_URL', 'http://localhost:3000');
        // Redirect to register page if new user, login page if existing
        $redirectPath = $user->wasRecentlyCreated ? '/register' : '/login';
        return redirect()->away($frontendUrl . $redirectPath . '?token=' . $token);
    }

    // ─────────────────────────────────────────────────────────────
    // FORGOT PASSWORD
    // ─────────────────────────────────────────────────────────────

    public function forgotPassword(Request $request): JsonResponse
    {
        $request->validate(['email' => 'required|email']);
        $user = User::where('email', $request->email)->first();

        // Always return success (don't reveal if email exists)
        if (!$user) {
            return response()->json(['success'=>true,'message'=>'If that email is registered, a 6-digit code was sent.']);
        }

        // Generate 6-digit OTP
        $otp = str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        \Illuminate\Support\Facades\Cache::put("otp_{$user->id}", $otp, now()->addMinutes(10));

        $user->update([
            'password_reset_token'   => Hash::make($otp),
            'password_reset_expires' => now()->addMinutes(10),
        ]);

        // Send OTP email
        Mail::send([], [], function ($message) use ($user, $otp) {
            $message->to($user->email)
                ->subject('Your EduLink verification code')
                ->html("
                <div style='font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px;'>
                    <div style='background:#1E1B4B;border-radius:16px;padding:32px;text-align:center;'>
                        <h1 style='color:#fff;font-size:24px;margin:0 0 8px;'>EduLink</h1>
                        <p style='color:rgba(255,255,255,0.7);margin:0 0 24px;'>Password Reset Code</p>
                        <div style='background:#7C3AED;border-radius:12px;padding:24px;margin:0 0 24px;'>
                            <p style='color:rgba(255,255,255,0.8);font-size:14px;margin:0 0 8px;'>Your verification code</p>
                            <div style='font-size:42px;font-weight:900;letter-spacing:12px;color:#fff;font-family:monospace;'>{$otp}</div>
                        </div>
                        <p style='color:rgba(255,255,255,0.5);font-size:13px;margin:0;'>Expires in 10 minutes. If you did not request this, ignore this email.</p>
                    </div>
                </div>");
        });

        return response()->json(['success'=>true,'message'=>'If that email is registered, a 6-digit code was sent.']);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'email'    => 'required|email',
            'token'    => 'required|string',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::where('email', $request->email)
            ->whereNotNull('password_reset_token')
            ->where('password_reset_expires', '>', now())
            ->first();

        if (!$user || !Hash::check($request->token, $user->password_reset_token)) {
            return response()->json(['success' => false, 'message' => 'Invalid or expired reset token.'], 422);
        }

        $user->update([
            'password'               => Hash::make($request->password),
            'password_reset_token'   => null,
            'password_reset_expires' => null,
        ]);

        // Revoke all existing tokens
        $user->tokens()->delete();

        return response()->json(['success' => true, 'message' => 'Password reset successfully. Please login.']);
    }

    // ─────────────────────────────────────────────────────────────
    // GET CURRENT USER
    // ─────────────────────────────────────────────────────────────

    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load('role', 'school', 'settings');
        return response()->json(['success' => true, 'user' => $this->formatUser($user)]);
    }

    // ─────────────────────────────────────────────────────────────
    // UPDATE PROFILE
    // ─────────────────────────────────────────────────────────────

    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'first_name'    => 'sometimes|string|max:80',
            'last_name'     => 'sometimes|string|max:80',
            'bio'           => 'nullable|string|max:500',
            'phone'         => 'nullable|string|max:30',
            'grade'         => 'nullable|string|max:30',
            'profile_photo' => 'nullable|image|max:5120',
            'cover_photo'   => 'nullable|image|max:10240',
        ]);

        if ($request->hasFile('profile_photo')) {
            if ($user->profile_photo && !str_starts_with($user->profile_photo, 'http')) {
                Storage::disk('public')->delete($user->profile_photo);
            }
            $validated['profile_photo'] = $request->file('profile_photo')
                ->store("avatars/{$user->id}", 'public');
        }

        if ($request->hasFile('cover_photo')) {
            if ($user->cover_photo) {
                Storage::disk('public')->delete($user->cover_photo);
            }
            $validated['cover_photo'] = $request->file('cover_photo')
                ->store("covers/{$user->id}", 'public');
        }

        $user->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Profile updated.',
            'user'    => $this->formatUser($user->fresh(['role', 'school', 'settings'])),
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => 'required|string',
            'password'         => 'required|string|min:8|confirmed',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['success' => false, 'message' => 'Current password is incorrect.'], 422);
        }

        $user->update(['password' => Hash::make($request->password)]);
        // Revoke other tokens
        $user->tokens()->where('id', '!=', $user->currentAccessToken()->id)->delete();

        return response()->json(['success' => true, 'message' => 'Password changed successfully.']);
    }

    // ─────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────

    private function generateUsername(string $first, string $last): string
    {
        $base     = Str::slug($first . $last);
        $username = $base;
        $i        = 1;
        while (User::where('username', $username)->exists()) {
            $username = $base . $i;
            $i++;
        }
        return $username;
    }

    private function formatUser(User $user): array
    {
        return [
            'id'            => $user->id,
            'first_name'    => $user->first_name,
            'last_name'     => $user->last_name,
            'full_name'     => $user->first_name . ' ' . $user->last_name,
            'username'      => $user->username,
            'email'         => $user->email,
            'role'          => $user->role->name ?? 'student',
            'school_id'     => $user->school_id,
            'school'        => $user->school ? [
                'id'   => $user->school->id,
                'name' => $user->school->name,
                'slug' => $user->school->slug,
            ] : null,
            'profile_photo' => $user->profile_photo
                ? (str_starts_with($user->profile_photo, 'http')
                    ? $user->profile_photo
                    : Storage::disk('public')->url($user->profile_photo))
                : null,
            'cover_photo'   => $user->cover_photo
                ? Storage::disk('public')->url($user->cover_photo)
                : null,
            'bio'           => $user->bio,
            'grade'         => $user->grade,
            'is_online'     => (bool) $user->is_online,
            'last_seen'     => $user->last_seen?->toISOString(),
            'created_at'    => $user->created_at->toISOString(),
            'settings'      => $user->settings ? [
                'dark_mode'    => (bool) $user->settings->dark_mode,
                'language'     => $user->settings->language,
                'theme'        => $user->settings->theme,
                'notifications_enabled' => (bool) $user->settings->notifications_enabled,
            ] : null,
        ];
    }

    public function verifyOtp(\Illuminate\Http\Request $request): JsonResponse
    {
        $request->validate(['email'=>'required|email','otp'=>'required|string|size:6']);
        $user = \App\Models\User::where('email',$request->email)->whereNotNull('password_reset_token')->where('password_reset_expires','>',now())->first();
        if (!$user) return response()->json(['success'=>false,'message'=>'Invalid or expired code.'],422);
        $cacheKey = "otp_{$user->id}";
        $cached   = \Illuminate\Support\Facades\Cache::get($cacheKey);
        if (!$cached || $cached !== $request->otp) return response()->json(['success'=>false,'message'=>'Incorrect code. Try again.'],422);
        $resetToken = Str::random(64);
        $user->update(['password_reset_token'=>Hash::make($resetToken),'password_reset_expires'=>now()->addMinutes(15)]);
        \Illuminate\Support\Facades\Cache::forget($cacheKey);
        return response()->json(['success'=>true,'reset_token'=>$resetToken]);
    }

    public function updateSettings(\Illuminate\Http\Request $request): JsonResponse
    {
        $validated = $request->validate([
            'dark_mode'=>'boolean','language'=>'string|in:en,am,om,ti,so,ar,fr',
            'notifications_enabled'=>'boolean','email_notifications'=>'boolean',
            'sound_enabled'=>'boolean','show_online_status'=>'boolean',
            'allow_messages_from'=>'in:everyone,classmates,nobody',
            'theme'=>'string|in:purple,blue,green,orange,pink',
            'font_size'=>'in:small,medium,large',
        ]);
        \App\Models\UserSetting::updateOrCreate(['user_id'=>$request->user()->id],$validated);
        return response()->json(['success'=>true,'message'=>'Settings saved.']);
    }

    public function publicProfile(\Illuminate\Http\Request $request, string $username): JsonResponse
    {
        $user = \App\Models\User::where('username',$username)->with('role','school','settings')->firstOrFail();
        if ($user->settings && !$user->settings->show_online_status) { $user->is_online=false; $user->last_seen=null; }
        return response()->json(['success'=>true,'user'=>$this->formatUser($user)]);
    }

    public function offline(\Illuminate\Http\Request $request): JsonResponse
    {
        $request->user()?->update(['is_online'=>0,'last_seen'=>now()]);
        return response()->json(['success'=>true]);
    }
}
