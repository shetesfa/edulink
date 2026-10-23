<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    /**
     * POST /api/device-tokens - called once by the Flutter app after login
     * and whenever Firebase issues a new token, so push notifications know
     * where to deliver.
     */
    public function store(Request $request)
    {
        $request->validate([
            'token' => ['required', 'string', 'max:500'],
            'platform' => ['nullable', 'in:android,ios,web,desktop'],
        ]);

        DeviceToken::updateOrCreate(
            ['user_id' => $request->user()->id, 'token' => $request->token],
            ['platform' => $request->platform ?? 'android']
        );

        return response()->json(['success' => true, 'message' => 'Device registered for push notifications.']);
    }

    /**
     * DELETE /api/device-tokens - called on logout so a signed-out device
     * stops receiving pushes meant for that account.
     */
    public function destroy(Request $request)
    {
        $request->validate(['token' => ['required', 'string']]);

        DeviceToken::where('user_id', $request->user()->id)->where('token', $request->token)->delete();

        return response()->json(['success' => true, 'message' => 'Device unregistered.']);
    }
}
