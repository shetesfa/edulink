<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\UserSetting;
use App\Models\Role;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Socialite\Facades\Socialite;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Http;
use Illuminate\Http\Request;

class GoogleAuthController extends Controller
{
    /**
     * GET /api/auth/google
     * Redirects the browser to Google's consent screen.
     */
    public function redirect()
    {
        return Socialite::driver('google')
            ->stateless()
            ->with(['prompt' => 'select_account'])
            ->redirect();
    }

    /**
     * GET /api/auth/google/callback
     * Handles the return trip from Google, creates/logs in the user,
     * and issues a Sanctum token.
     */
    public function callback(Request $request)
    {
        try {
            $googleUser = Socialite::driver('google')->stateless()->user();
        } catch (\Exception $e) {
            Log::warning('Google OAuth failed: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Google sign-in failed. Please try again.',
            ], 401);
        }

        $user = User::where('google_id', $googleUser->getId())
            ->orWhere('email', $googleUser->getEmail())
            ->first();

        if (!$user) {
            [$firstName, $lastName] = $this->splitName($googleUser->getName());

            $user = User::create([
                'first_name'       => $firstName,
                'last_name'        => $lastName ?: '.',
                'email'            => $googleUser->getEmail(),
                'username'         => $this->generateUsername($googleUser->getEmail()),
                'password'         => Hash::make(Str::random(32)),
                'google_id'        => $googleUser->getId(),
                'profile_photo'    => $googleUser->getAvatar(),
                'email_verified_at'=> now(),
                'role_id'          => Role::STUDENT,
            ]);

            UserSetting::create(['user_id' => $user->id]);
        } elseif (!$user->google_id) {
            $user->update(['google_id' => $googleUser->getId()]);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'This account has been deactivated.',
            ], 403);
        }

        $token = $user->createToken('edulink-auth')->plainTextToken;
        $user->update(['is_online' => true, 'last_seen' => now()]);

        if ($request->wantsJson() || $request->ajax()) {
            return response()->json([
                'success' => true,
                'message' => 'Logged in with Google successfully.',
                'data' => ['user' => $user->load('role', 'settings'), 'token' => $token],
            ]);
        }

        $userData = json_encode($user->load('role', 'settings'));
        $redirectUrl = 'http://localhost:3000/?token=' . urlencode($token) . '&user=' . urlencode($userData);

        return response("
<!DOCTYPE html>
<html>
<head>
    <title>Logging in to EduLink...</title>
    <meta charset='utf-8'>
</head>
<body style='font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; background: #0F172A; color: white;'>
    <div style='text-align: center;'>
        <h2>✨ Logged in with Google Successfully!</h2>
        <p>Redirecting to EduLink Desktop App...</p>
    </div>
    <script>
        const token = '{$token}';
        const user = {$userData};
        
        localStorage.setItem('edulink_auth_token', token);
        localStorage.setItem('flutter.edulink_auth_token', token);
        localStorage.setItem('current_user', JSON.stringify(user));

        window.location.href = '{$redirectUrl}';
    </script>
</body>
</html>
", 200, ['Content-Type' => 'text/html']);
    }

    /**
     * POST /api/auth/google/mobile
     * Verifies the ID token issued by the native Android/iOS Google client.
     */
    public function mobileCallback(Request $request)
    {
        $data = $request->validate(['id_token' => ['required', 'string']]);
        $clientId = config('services.google.client_id');

        if (!$clientId) {
            return response()->json([
                'success' => false,
                'message' => 'Google sign-in has not been configured on this server.',
            ], 503);
        }

        try {
            $response = Http::timeout(10)->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $data['id_token'],
            ]);
        } catch (\Throwable $e) {
            Log::warning('Google ID token validation failed: '.$e->getMessage());
            return response()->json(['success' => false, 'message' => 'Google could not verify this sign-in.'], 503);
        }

        if (!$response->successful()
            || $response->json('aud') !== $clientId
            || $response->json('email_verified') !== 'true'
            || !$response->json('sub')
            || !$response->json('email')) {
            return response()->json(['success' => false, 'message' => 'Invalid Google sign-in token.'], 401);
        }

        return $this->loginGoogleUser(
            $response->json('sub'),
            $response->json('email'),
            $response->json('name') ?? $response->json('email'),
            $response->json('picture'),
        );
    }

    private function loginGoogleUser(string $googleId, string $email, ?string $name, ?string $avatar)
    {
        $user = User::where('google_id', $googleId)->orWhere('email', $email)->first();

        if (!$user) {
            [$firstName, $lastName] = $this->splitName($name);
            $user = User::create([
                'first_name'       => $firstName,
                'last_name'        => $lastName ?: '.',
                'email'            => $email,
                'username'         => $this->generateUsername($email),
                'password'         => Hash::make(Str::random(32)),
                'google_id'        => $googleId,
                'profile_photo'    => $avatar,
                'email_verified_at'=> now(),
                'role_id'          => Role::STUDENT,
            ]);
            UserSetting::create(['user_id' => $user->id]);
        } elseif (!$user->google_id) {
            $user->update(['google_id' => $googleId]);
        }

        if (!$user->is_active) {
            return response()->json(['success' => false, 'message' => 'This account has been deactivated.'], 403);
        }

        $token = $user->createToken('edulink-mobile')->plainTextToken;
        $user->update(['is_online' => true, 'last_seen' => now()]);

        return response()->json([
            'success' => true,
            'message' => 'Logged in with Google successfully.',
            'data' => ['user' => $user->load('role', 'settings'), 'token' => $token],
        ]);
    }

    private function splitName(?string $fullName): array
    {
        $parts = explode(' ', trim($fullName ?? ''), 2);
        return [$parts[0] ?? 'User', $parts[1] ?? ''];
    }

    /**
     * Generate a unique username from an email address.
     * e.g. john.doe@gmail.com → johndoe, johndoe2, johndoe3, ...
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
