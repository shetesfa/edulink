<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SchoolClass;
use App\Models\Lesson;
use App\Models\Assignment;
use App\Models\Quiz;
use App\Models\User;
use Illuminate\Http\Request;

class SearchController extends Controller
{
    /**
     * GET /api/search?query=...
     * Searches only within classes the user actually belongs to (teaching
     * or enrolled) - never leaks another class's content.
     */
    public function index(Request $request)
    {
        $request->validate(['query' => ['required', 'string', 'min:2']]);
        $term = $request->query('query');
        $user = $request->user();

        $myClassIds = $user->classesTaught()->pluck('id')
            ->merge($user->enrolledClasses()->pluck('classes.id'));

        $classes = SchoolClass::whereIn('id', $myClassIds)
            ->where('name', 'like', "%{$term}%")
            ->limit(10)->get(['id', 'name', 'subject']);

        $lessons = Lesson::whereIn('class_id', $myClassIds)
            ->where('title', 'like', "%{$term}%")
            ->limit(10)->get(['id', 'title', 'class_id']);

        $assignments = Assignment::whereIn('class_id', $myClassIds)
            ->where('title', 'like', "%{$term}%")
            ->limit(10)->get(['id', 'title', 'class_id']);

        $quizzes = Quiz::whereIn('class_id', $myClassIds)
            ->where('title', 'like', "%{$term}%")
            ->limit(10)->get(['id', 'title', 'class_id']);

        // People search — search by name OR username (prefix @ to search by username)
        $usernameTerm = ltrim($term, '@'); // strip @ prefix if user typed @username
        $people = User::where(function ($q) use ($term, $usernameTerm, $user) {
                $q->where('first_name', 'like', "%{$term}%")
                  ->orWhere('last_name', 'like', "%{$term}%")
                  ->orWhere('username', 'like', "%{$usernameTerm}%");
                // If user has a school, also search within same school
                if ($user->school_id) {
                    $q->where('school_id', $user->school_id);
                }
            })
            ->where('id', '!=', $user->id)
            ->limit(10)
            ->get(['id', 'first_name', 'last_name', 'email', 'username', 'profile_photo', 'role_id']);

        return response()->json([
            'success' => true,
            'data' => [
                'classes'     => $classes,
                'lessons'     => $lessons,
                'assignments' => $assignments,
                'quizzes'     => $quizzes,
                'people'      => $people,
            ],
        ]);
    }
}
