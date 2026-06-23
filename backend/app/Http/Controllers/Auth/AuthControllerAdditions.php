<?php
// ─── Add to AuthController — OTP verification + update settings ─
// These methods go inside the AuthController class

/*
 * verifyOtp  — validates the 6-digit code emailed during forgot-password
 * updateSettings — persist user preference changes from Settings page
 * publicProfile  — view another user's public profile
 * offline        — called by socket server to set user offline
 */

// ── verifyOtp ─────────────────────────────────────────────────
public function verifyOtp(\Illuminate\Http\Request $request): \Illuminate\Http\JsonResponse
{
    $request->validate([
        'email' => 'required|email',
        'otp'   => 'required|string|size:6',
    ]);

    $user = \App\Models\User::where('email', $request->email)
        ->whereNotNull('password_reset_token')
        ->where('password_reset_expires', '>', now())
        ->first();

    if (!$user) {
        return response()->json(['success' => false, 'message' => 'Invalid or expired code. Please request a new one.'], 422);
    }

    // The reset token stores a bcrypt hash of "OTP_CODE|TIMESTAMP"
    // We compare the OTP itself (stored as plain in cache for 10 min)
    $cacheKey    = "otp_{$user->id}";
    $cachedOtp   = \Illuminate\Support\Facades\Cache::get($cacheKey);

    if (!$cachedOtp || $cachedOtp !== $request->otp) {
        return response()->json(['success' => false, 'message' => 'Incorrect code. Please try again.'], 422);
    }

    // OTP verified — issue a short-lived reset token
    $resetToken = \Illuminate\Support\Str::random(64);
    $user->update([
        'password_reset_token'   => \Illuminate\Support\Facades\Hash::make($resetToken),
        'password_reset_expires' => now()->addMinutes(15),
    ]);

    \Illuminate\Support\Facades\Cache::forget($cacheKey);

    return response()->json(['success' => true, 'reset_token' => $resetToken]);
}

// ── Override forgotPassword to also generate + cache a 6-digit OTP ──
// Replace the existing forgotPassword method body with this:
public function forgotPassword(\Illuminate\Http\Request $request): \Illuminate\Http\JsonResponse
{
    $request->validate(['email' => 'required|email']);

    $user = \App\Models\User::where('email', $request->email)->first();

    // Always return success (don't reveal if email exists)
    if (!$user) {
        return response()->json(['success' => true, 'message' => 'If that email is registered, you will receive a code shortly.']);
    }

    // Generate 6-digit OTP
    $otp = str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);

    // Store OTP in cache for 10 minutes
    \Illuminate\Support\Facades\Cache::put("otp_{$user->id}", $otp, now()->addMinutes(10));

    // Store reset marker on user (needed for verifyOtp lookup)
    $user->update([
        'password_reset_token'   => \Illuminate\Support\Facades\Hash::make($otp),
        'password_reset_expires' => now()->addMinutes(10),
    ]);

    // Send email with OTP
    \Illuminate\Support\Facades\Mail::send([], [], function ($message) use ($user, $otp) {
        $message->to($user->email)
            ->subject('Your EduLink verification code')
            ->html("
                <div style='font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;'>
                    <div style='background:#1E1B4B;border-radius:16px;padding:32px;text-align:center;'>
                        <h1 style='color:#fff;font-size:24px;margin:0 0 8px;'>EduLink</h1>
                        <p style='color:rgba(255,255,255,0.7);margin:0 0 24px;'>Password Reset</p>
                        <div style='background:#7C3AED;border-radius:12px;padding:24px;margin:0 0 24px;'>
                            <p style='color:rgba(255,255,255,0.8);font-size:14px;margin:0 0 8px;'>Your verification code</p>
                            <div style='font-size:42px;font-weight:900;letter-spacing:12px;color:#fff;font-family:monospace;'>{$otp}</div>
                        </div>
                        <p style='color:rgba(255,255,255,0.5);font-size:13px;margin:0;'>This code expires in 10 minutes.<br>If you didn't request this, ignore this email.</p>
                    </div>
                    <p style='color:#94A3B8;font-size:12px;text-align:center;margin-top:16px;'>EduLink — Learn, Teach and Connect</p>
                </div>
            ");
    });

    return response()->json(['success' => true, 'message' => 'If that email is registered, you will receive a code shortly.']);
}

// ── updateSettings ────────────────────────────────────────────
public function updateSettings(\Illuminate\Http\Request $request): \Illuminate\Http\JsonResponse
{
    $user = $request->user();

    $validated = $request->validate([
        'dark_mode'             => 'boolean',
        'language'              => 'string|in:en,am,om,ti,so,ar,fr',
        'notifications_enabled' => 'boolean',
        'email_notifications'   => 'boolean',
        'sound_enabled'         => 'boolean',
        'show_online_status'    => 'boolean',
        'allow_messages_from'   => 'in:everyone,classmates,nobody',
        'theme'                 => 'string|in:purple,blue,green,orange,pink',
        'font_size'             => 'in:small,medium,large',
    ]);

    \App\Models\UserSetting::updateOrCreate(
        ['user_id' => $user->id],
        $validated
    );

    return response()->json(['success' => true, 'message' => 'Settings saved.']);
}

// ── publicProfile ─────────────────────────────────────────────
public function publicProfile(\Illuminate\Http\Request $request, string $username): \Illuminate\Http\JsonResponse
{
    $user = \App\Models\User::where('username', $username)->with('role','school','settings')->firstOrFail();

    // Respect privacy settings
    $settings = $user->settings;
    if ($settings && !$settings->show_online_status) {
        $user->is_online  = false;
        $user->last_seen  = null;
    }

    return response()->json(['success' => true, 'user' => $this->formatUser($user)]);
}

// ── offline (called by Socket.io server) ─────────────────────
public function offline(\Illuminate\Http\Request $request): \Illuminate\Http\JsonResponse
{
    $request->user()?->update(['is_online' => 0, 'last_seen' => now()]);
    return response()->json(['success' => true]);
}
