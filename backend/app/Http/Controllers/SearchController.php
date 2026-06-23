<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Classes;
use App\Models\Lesson;
use App\Models\Assignment;
use App\Models\Quiz;
use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

// ─────────────────────────────────────────────────────────────
// SearchController
// ─────────────────────────────────────────────────────────────
class SearchController extends Controller
{
    public function search(Request $request): JsonResponse
    {
        $request->validate(['q' => 'required|string|min:2|max:100']);
        $q    = '%' . $request->q . '%';
        $type = $request->type ?? 'all';
        $user = $request->user();

        $results = [];

        if (in_array($type, ['all','users'])) {
            $results['users'] = User::where('school_id', $user->school_id)
                ->where(function ($sq) use ($q) {
                    $sq->where('first_name','LIKE',$q)
                       ->orWhere('last_name','LIKE',$q)
                       ->orWhere('email','LIKE',$q)
                       ->orWhere('username','LIKE',$q);
                })
                ->with('role','school')
                ->take(10)->get()
                ->map(fn($u) => [
                    'id'           => $u->id,
                    'first_name'   => $u->first_name,
                    'last_name'    => $u->last_name,
                    'full_name'    => $u->first_name.' '.$u->last_name,
                    'username'     => $u->username,
                    'email'        => $u->email,
                    'role'         => $u->role?->name,
                    'profile_photo'=> $u->profile_photo,
                    'is_online'    => (bool)$u->is_online,
                    'school'       => $u->school ? ['id'=>$u->school->id,'name'=>$u->school->name] : null,
                ]);
        }

        if (in_array($type, ['all','classes'])) {
            // Only classes the user is in (or teaches)
            $classQuery = Classes::where('school_id', $user->school_id)
                ->where(function ($sq) use ($q) {
                    $sq->where('name','LIKE',$q)->orWhere('subject','LIKE',$q);
                });

            if ($user->role->name === 'student') {
                $classQuery->whereHas('enrollments', fn($eq) => $eq->where('student_id',$user->id));
            } elseif ($user->role->name === 'teacher') {
                $classQuery->where('teacher_id', $user->id);
            }

            $results['classes'] = $classQuery->with(['teacher','grade'])
                ->withCount('enrollments')->take(10)->get()
                ->map(fn($c) => [
                    'id'               => $c->id,
                    'name'             => $c->name,
                    'subject'          => $c->subject,
                    'color'            => $c->color,
                    'join_code'        => $c->join_code,
                    'enrollments_count'=> $c->enrollments_count,
                    'teacher'          => ['full_name' => $c->teacher?->first_name.' '.$c->teacher?->last_name],
                ]);
        }

        if (in_array($type, ['all','lessons'])) {
            $classIds = $this->getUserClassIds($user);
            $results['lessons'] = Lesson::whereIn('class_id', $classIds)
                ->where('is_published', 1)
                ->where(function ($sq) use ($q) {
                    $sq->where('title','LIKE',$q)->orWhere('description','LIKE',$q);
                })
                ->with('class')
                ->take(10)->get()
                ->map(fn($l) => [
                    'id'         => $l->id,
                    'title'      => $l->title,
                    'description'=> $l->description,
                    'class_id'   => $l->class_id,
                    'class_name' => $l->class?->name,
                    'views'      => $l->views,
                ]);
        }

        if (in_array($type, ['all','assignments'])) {
            $classIds = $this->getUserClassIds($user);
            $results['assignments'] = Assignment::whereIn('class_id', $classIds)
                ->where('is_published', 1)
                ->where('title','LIKE',$q)
                ->with('class')
                ->take(10)->get()
                ->map(fn($a) => [
                    'id'         => $a->id,
                    'title'      => $a->title,
                    'class_id'   => $a->class_id,
                    'class_name' => $a->class?->name,
                    'due_date'   => $a->due_date?->toISOString(),
                    'max_score'  => $a->max_score,
                ]);
        }

        if (in_array($type, ['all','quizzes'])) {
            $classIds = $this->getUserClassIds($user);
            $results['quizzes'] = Quiz::whereIn('class_id', $classIds)
                ->where('is_published', 1)
                ->where('title','LIKE',$q)
                ->with('class')
                ->take(10)->get()
                ->map(fn($qz) => [
                    'id'              => $qz->id,
                    'title'           => $qz->title,
                    'class_id'        => $qz->class_id,
                    'class_name'      => $qz->class?->name,
                    'questions_count' => $qz->questions()->count(),
                ]);
        }

        return response()->json(['success' => true, 'results' => $results]);
    }

    private function getUserClassIds($user): array
    {
        if ($user->role->name === 'student') {
            return $user->enrollments()->pluck('class_id')->toArray();
        } elseif ($user->role->name === 'teacher') {
            return Classes::where('teacher_id', $user->id)->pluck('id')->toArray();
        }
        return Classes::where('school_id', $user->school_id)->pluck('id')->toArray();
    }
}
