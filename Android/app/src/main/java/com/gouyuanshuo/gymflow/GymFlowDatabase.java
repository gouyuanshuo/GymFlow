package com.gouyuanshuo.gymflow;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

public final class GymFlowDatabase extends SQLiteOpenHelper {
    private static final String DATABASE_NAME = "gymflow_android.db";
    private static final int DATABASE_VERSION = 1;
    private static GymFlowDatabase instance;

    public static synchronized GymFlowDatabase get(Context context) {
        if (instance == null) instance = new GymFlowDatabase(context.getApplicationContext());
        return instance;
    }

    private GymFlowDatabase(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override public void onConfigure(SQLiteDatabase db) {
        super.onConfigure(db);
        db.setForeignKeyConstraintsEnabled(true);
    }

    @Override public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE exercise_definitions (" +
                "id TEXT PRIMARY KEY, name TEXT NOT NULL, muscle_group TEXT NOT NULL," +
                "secondary_muscles TEXT NOT NULL DEFAULT '', equipment TEXT NOT NULL," +
                "default_rest INTEGER, default_sets INTEGER, default_reps INTEGER," +
                "notes TEXT NOT NULL DEFAULT '', is_custom INTEGER NOT NULL DEFAULT 0," +
                "is_archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE plans (" +
                "id TEXT PRIMARY KEY, name TEXT NOT NULL, notes TEXT NOT NULL DEFAULT ''," +
                "created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, sort_order INTEGER NOT NULL," +
                "playlist_id TEXT)");
        db.execSQL("CREATE TABLE plan_exercises (" +
                "id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, exercise_id TEXT, name_snapshot TEXT NOT NULL," +
                "target_sets INTEGER NOT NULL, target_reps INTEGER NOT NULL, target_weight REAL NOT NULL," +
                "rest_seconds INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL," +
                "FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE CASCADE)");
        db.execSQL("CREATE TABLE sessions (" +
                "id TEXT PRIMARY KEY, plan_id TEXT, plan_name TEXT NOT NULL, started_at INTEGER NOT NULL," +
                "completed_at INTEGER, notes TEXT NOT NULL DEFAULT '', status TEXT NOT NULL," +
                "current_exercise_index INTEGER NOT NULL DEFAULT 0, current_set_number INTEGER NOT NULL DEFAULT 1," +
                "playlist_id TEXT, playlist_name TEXT)");
        db.execSQL("CREATE TABLE exercise_records (" +
                "id TEXT PRIMARY KEY, session_id TEXT NOT NULL, exercise_id TEXT, name_snapshot TEXT NOT NULL," +
                "sort_order INTEGER NOT NULL, rest_seconds INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT ''," +
                "FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE)");
        db.execSQL("CREATE TABLE set_records (" +
                "id TEXT PRIMARY KEY, record_id TEXT NOT NULL, set_number INTEGER NOT NULL," +
                "weight REAL NOT NULL, repetitions INTEGER NOT NULL, is_completed INTEGER NOT NULL DEFAULT 0," +
                "completed_at INTEGER, is_warmup INTEGER NOT NULL DEFAULT 0," +
                "FOREIGN KEY(record_id) REFERENCES exercise_records(id) ON DELETE CASCADE)");
        db.execSQL("CREATE TABLE tracks (" +
                "id TEXT PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL DEFAULT ''," +
                "stored_filename TEXT NOT NULL UNIQUE, original_filename TEXT NOT NULL, extension TEXT NOT NULL," +
                "duration_ms INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, sort_order INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE playlists (" +
                "id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL," +
                "updated_at INTEGER NOT NULL, sort_order INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE playlist_tracks (" +
                "playlist_id TEXT NOT NULL, track_id TEXT NOT NULL, sort_order INTEGER NOT NULL," +
                "PRIMARY KEY(playlist_id, track_id)," +
                "FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE," +
                "FOREIGN KEY(track_id) REFERENCES tracks(id) ON DELETE CASCADE)");
        db.execSQL("CREATE INDEX idx_plan_exercises_plan ON plan_exercises(plan_id, sort_order)");
        db.execSQL("CREATE INDEX idx_records_session ON exercise_records(session_id, sort_order)");
        db.execSQL("CREATE INDEX idx_sets_record ON set_records(record_id, set_number)");
        db.execSQL("CREATE INDEX idx_sessions_status_date ON sessions(status, started_at DESC)");
        seedDefaults(db);
    }

    @Override public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        // Version 1 is the first Android schema. Future upgrades must preserve local history.
    }

    public synchronized void ensureSeeded() {
        // Opening a new database runs onCreate(), which installs the first-launch library and plans.
        // Do not reseed merely because the user deliberately deleted all workout data.
        getWritableDatabase();
    }

    private void seedDefaults(SQLiteDatabase db) {
        db.beginTransaction();
        try {
            if (count(db, "exercise_definitions") == 0) seedExercises(db);
            if (count(db, "plans") == 0) seedPlans(db);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    private void seedExercises(SQLiteDatabase db) {
        Object[][] seeds = new Object[][] {
                {"杠铃卧推", "胸部", "杠铃", 180, 4, 8},
                {"上斜哑铃推胸", "胸部", "哑铃", null, null, null},
                {"哑铃卧推", "胸部", "哑铃", null, null, null},
                {"绳索夹胸", "胸部", "绳索器械", null, null, null},
                {"蝴蝶机夹胸", "胸部", "固定器械", null, null, null},
                {"高位下拉", "背部", "绳索器械", null, null, null},
                {"引体向上", "背部", "自重", null, null, null},
                {"坐姿绳索划船", "背部", "绳索器械", null, null, null},
                {"杠铃划船", "背部", "杠铃", null, null, null},
                {"单臂哑铃划船", "背部", "哑铃", null, null, null},
                {"哑铃肩推", "肩部", "哑铃", null, null, null},
                {"杠铃推举", "肩部", "杠铃", null, null, null},
                {"哑铃侧平举", "肩部", "哑铃", null, null, null},
                {"俯身哑铃飞鸟", "肩部", "哑铃", null, null, null},
                {"面拉", "肩部", "绳索器械", null, null, null},
                {"杠铃弯举", "肱二头肌", "杠铃", null, null, null},
                {"二头弯举", "肱二头肌", "哑铃", null, null, null},
                {"哑铃弯举", "肱二头肌", "哑铃", null, null, null},
                {"锤式弯举", "肱二头肌", "哑铃", null, null, null},
                {"绳索弯举", "肱二头肌", "绳索器械", null, null, null},
                {"绳索下压", "肱三头肌", "绳索器械", null, null, null},
                {"哑铃颈后臂屈伸", "肱三头肌", "哑铃", null, null, null},
                {"仰卧臂屈伸", "肱三头肌", "杠铃", null, null, null},
                {"窄距卧推", "肱三头肌", "杠铃", null, null, null},
                {"杠铃深蹲", "股四头肌", "杠铃", null, null, null},
                {"腿举", "股四头肌", "固定器械", null, null, null},
                {"罗马尼亚硬拉", "腘绳肌", "杠铃", null, null, null},
                {"腿屈伸", "股四头肌", "固定器械", null, null, null},
                {"腿弯举", "腘绳肌", "固定器械", null, null, null},
                {"保加利亚分腿蹲", "股四头肌", "哑铃", null, null, null},
                {"臀推", "臀部", "杠铃", null, null, null},
                {"提踵", "小腿", "固定器械", null, null, null},
                {"平板支撑", "核心", "自重", null, null, null},
                {"悬垂举腿", "核心", "自重", null, null, null},
                {"绳索卷腹", "核心", "绳索器械", null, null, null},
                {"跑步机", "有氧", "有氧器械", null, null, null},
                {"健身车", "有氧", "有氧器械", null, null, null},
                {"划船机", "有氧", "有氧器械", null, null, null}
        };
        long now = System.currentTimeMillis();
        for (Object[] seed : seeds) {
            ContentValues values = new ContentValues();
            values.put("id", stableId("exercise:" + seed[0]));
            values.put("name", (String) seed[0]);
            values.put("muscle_group", (String) seed[1]);
            values.put("equipment", (String) seed[2]);
            putNullable(values, "default_rest", (Integer) seed[3]);
            putNullable(values, "default_sets", (Integer) seed[4]);
            putNullable(values, "default_reps", (Integer) seed[5]);
            values.put("is_custom", 0);
            values.put("is_archived", 0);
            values.put("created_at", now);
            values.put("updated_at", now);
            db.insertOrThrow("exercise_definitions", null, values);
        }
    }

    private void seedPlans(SQLiteDatabase db) {
        seedPlan(db, "胸部与手臂", 0, new Object[][] {
                {"杠铃卧推", 4, 8, 60d, 180}, {"上斜哑铃推胸", 4, 10, 20d, 120},
                {"绳索夹胸", 3, 12, 15d, 90}, {"二头弯举", 4, 10, 12d, 90},
                {"绳索下压", 4, 12, 20d, 90}
        });
        seedPlan(db, "背部与肩部", 1, new Object[][] {
                {"高位下拉", 4, 10, 55d, 120}, {"坐姿绳索划船", 4, 10, 50d, 120},
                {"单臂哑铃划船", 4, 10, 24d, 120}, {"哑铃肩推", 4, 10, 16d, 120},
                {"哑铃侧平举", 4, 12, 7d, 75}
        });
        seedPlan(db, "腿部", 2, new Object[][] {
                {"杠铃深蹲", 4, 8, 60d, 180}, {"腿举", 4, 10, 120d, 180},
                {"罗马尼亚硬拉", 4, 10, 50d, 150}, {"腿弯举", 4, 12, 35d, 90}
        });
    }

    private void seedPlan(SQLiteDatabase db, String name, int order, Object[][] exercises) {
        String planId = stableId("plan:" + name);
        long now = System.currentTimeMillis();
        ContentValues plan = new ContentValues();
        plan.put("id", planId);
        plan.put("name", name);
        plan.put("created_at", now);
        plan.put("updated_at", now);
        plan.put("sort_order", order);
        db.insertOrThrow("plans", null, plan);
        for (int index = 0; index < exercises.length; index++) {
            Object[] item = exercises[index];
            ContentValues values = new ContentValues();
            values.put("id", stableId("plan-exercise:" + name + ":" + item[0]));
            values.put("plan_id", planId);
            values.put("exercise_id", stableId("exercise:" + item[0]));
            values.put("name_snapshot", (String) item[0]);
            values.put("target_sets", (Integer) item[1]);
            values.put("target_reps", (Integer) item[2]);
            values.put("target_weight", (Double) item[3]);
            values.put("rest_seconds", (Integer) item[4]);
            values.put("sort_order", index);
            db.insertOrThrow("plan_exercises", null, values);
        }
    }

    public synchronized List<Models.Plan> getPlans() {
        List<Models.Plan> values = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().query("plans", null, null, null, null, null,
                "sort_order ASC, created_at ASC")) {
            while (cursor.moveToNext()) values.add(readPlan(cursor));
        }
        for (Models.Plan plan : values) loadPlanExercises(plan);
        return values;
    }

    public synchronized Models.Plan getPlan(String id) {
        if (id == null) return null;
        try (Cursor cursor = getReadableDatabase().query("plans", null, "id=?", new String[] {id},
                null, null, null)) {
            if (!cursor.moveToFirst()) return null;
            Models.Plan plan = readPlan(cursor);
            loadPlanExercises(plan);
            return plan;
        }
    }

    private Models.Plan readPlan(Cursor cursor) {
        Models.Plan plan = new Models.Plan();
        plan.id = string(cursor, "id");
        plan.name = string(cursor, "name");
        plan.notes = string(cursor, "notes");
        plan.createdAt = number(cursor, "created_at");
        plan.updatedAt = number(cursor, "updated_at");
        plan.sortOrder = integer(cursor, "sort_order");
        plan.assignedPlaylistId = nullableString(cursor, "playlist_id");
        return plan;
    }

    private void loadPlanExercises(Models.Plan plan) {
        try (Cursor cursor = getReadableDatabase().query("plan_exercises", null, "plan_id=?",
                new String[] {plan.id}, null, null, "sort_order ASC")) {
            while (cursor.moveToNext()) {
                Models.PlannedExercise exercise = new Models.PlannedExercise();
                exercise.id = string(cursor, "id");
                exercise.exerciseId = nullableString(cursor, "exercise_id");
                exercise.name = string(cursor, "name_snapshot");
                exercise.targetSets = integer(cursor, "target_sets");
                exercise.targetRepetitions = integer(cursor, "target_reps");
                exercise.targetWeight = real(cursor, "target_weight");
                exercise.restSeconds = integer(cursor, "rest_seconds");
                exercise.notes = string(cursor, "notes");
                exercise.sortOrder = integer(cursor, "sort_order");
                plan.exercises.add(exercise);
            }
        }
    }

    public synchronized Models.Plan savePlan(Models.Plan plan) {
        String trimmed = plan.name == null ? "" : plan.name.trim();
        if (trimmed.isEmpty()) throw new IllegalArgumentException("计划名称不能为空");
        SQLiteDatabase db = getWritableDatabase();
        long now = System.currentTimeMillis();
        if (plan.id == null) {
            plan.id = randomId();
            plan.createdAt = now;
            plan.sortOrder = getPlans().size();
        }
        plan.name = trimmed;
        plan.updatedAt = now;
        db.beginTransaction();
        try {
            ContentValues values = new ContentValues();
            values.put("name", plan.name);
            values.put("notes", safe(plan.notes));
            values.put("created_at", plan.createdAt);
            values.put("updated_at", plan.updatedAt);
            values.put("sort_order", plan.sortOrder);
            putNullable(values, "playlist_id", plan.assignedPlaylistId);
            if (db.update("plans", values, "id=?", new String[] {plan.id}) == 0) {
                values.put("id", plan.id);
                db.insertOrThrow("plans", null, values);
            }
            db.delete("plan_exercises", "plan_id=?", new String[] {plan.id});
            for (int index = 0; index < plan.exercises.size(); index++) {
                Models.PlannedExercise exercise = plan.exercises.get(index);
                if (exercise.id == null) exercise.id = randomId();
                exercise.sortOrder = index;
                ContentValues row = new ContentValues();
                row.put("id", exercise.id);
                row.put("plan_id", plan.id);
                putNullable(row, "exercise_id", exercise.exerciseId);
                row.put("name_snapshot", safe(exercise.name));
                row.put("target_sets", Math.max(1, exercise.targetSets));
                row.put("target_reps", Math.max(0, exercise.targetRepetitions));
                row.put("target_weight", Math.max(0, exercise.targetWeight));
                row.put("rest_seconds", Math.max(0, exercise.restSeconds));
                row.put("notes", safe(exercise.notes));
                row.put("sort_order", index);
                db.insertOrThrow("plan_exercises", null, row);
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return plan;
    }

    public synchronized Models.Plan duplicatePlan(String id) {
        Models.Plan source = getPlan(id);
        if (source == null) return null;
        Models.Plan copy = source.copy();
        copy.id = null;
        copy.name = source.name + "（副本）";
        for (Models.PlannedExercise exercise : copy.exercises) exercise.id = null;
        return savePlan(copy);
    }

    public synchronized void deletePlan(String id) {
        getWritableDatabase().delete("plans", "id=?", new String[] {id});
    }

    public synchronized List<Models.ExerciseDefinition> getExercises(boolean includeArchived, String search, String muscle) {
        List<Models.ExerciseDefinition> values = new ArrayList<>();
        String normalizedSearch = normalize(search);
        try (Cursor cursor = getReadableDatabase().query("exercise_definitions", null, null, null,
                null, null, "is_archived ASC, muscle_group ASC, name COLLATE LOCALIZED ASC")) {
            while (cursor.moveToNext()) {
                Models.ExerciseDefinition value = readExercise(cursor);
                if (!includeArchived && value.archived) continue;
                if (muscle != null && !muscle.isEmpty() && !"全部".equals(muscle)
                        && !muscle.equals(value.muscleGroup)) continue;
                if (!normalizedSearch.isEmpty()
                        && !normalize(value.name + " " + value.muscleGroup + " " + value.equipment).contains(normalizedSearch)) continue;
                values.add(value);
            }
        }
        return values;
    }

    public synchronized Models.ExerciseDefinition getExercise(String id) {
        if (id == null) return null;
        try (Cursor cursor = getReadableDatabase().query("exercise_definitions", null, "id=?",
                new String[] {id}, null, null, null)) {
            return cursor.moveToFirst() ? readExercise(cursor) : null;
        }
    }

    private Models.ExerciseDefinition readExercise(Cursor cursor) {
        Models.ExerciseDefinition value = new Models.ExerciseDefinition();
        value.id = string(cursor, "id");
        value.name = string(cursor, "name");
        value.muscleGroup = string(cursor, "muscle_group");
        value.secondaryMuscleGroups = string(cursor, "secondary_muscles");
        value.equipment = string(cursor, "equipment");
        value.defaultRestSeconds = nullableInteger(cursor, "default_rest");
        value.defaultSets = nullableInteger(cursor, "default_sets");
        value.defaultRepetitions = nullableInteger(cursor, "default_reps");
        value.notes = string(cursor, "notes");
        value.custom = integer(cursor, "is_custom") != 0;
        value.archived = integer(cursor, "is_archived") != 0;
        value.createdAt = number(cursor, "created_at");
        value.updatedAt = number(cursor, "updated_at");
        return value;
    }

    public synchronized Models.ExerciseDefinition saveExercise(Models.ExerciseDefinition exercise) {
        String trimmed = exercise.name == null ? "" : exercise.name.trim();
        if (trimmed.isEmpty()) throw new IllegalArgumentException("动作名称不能为空");
        for (Models.ExerciseDefinition existing : getExercises(true, null, null)) {
            if (!existing.id.equals(exercise.id) && normalize(existing.name).equals(normalize(trimmed))) {
                throw new IllegalArgumentException("动作“" + trimmed + "”已经存在");
            }
        }
        long now = System.currentTimeMillis();
        if (exercise.id == null) {
            exercise.id = randomId();
            exercise.createdAt = now;
            exercise.custom = true;
        }
        exercise.name = trimmed;
        exercise.updatedAt = now;
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            ContentValues values = new ContentValues();
            values.put("name", exercise.name);
            values.put("muscle_group", safeDefault(exercise.muscleGroup, "其他"));
            values.put("secondary_muscles", safe(exercise.secondaryMuscleGroups));
            values.put("equipment", safeDefault(exercise.equipment, "其他"));
            putNullable(values, "default_rest", exercise.defaultRestSeconds);
            putNullable(values, "default_sets", exercise.defaultSets);
            putNullable(values, "default_reps", exercise.defaultRepetitions);
            values.put("notes", safe(exercise.notes));
            values.put("is_custom", exercise.custom ? 1 : 0);
            values.put("is_archived", exercise.archived ? 1 : 0);
            values.put("created_at", exercise.createdAt);
            values.put("updated_at", exercise.updatedAt);
            if (db.update("exercise_definitions", values, "id=?", new String[] {exercise.id}) == 0) {
                values.put("id", exercise.id);
                db.insertOrThrow("exercise_definitions", null, values);
            }
            ContentValues linkedName = new ContentValues();
            linkedName.put("name_snapshot", exercise.name);
            db.update("plan_exercises", linkedName, "exercise_id=?", new String[] {exercise.id});
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return exercise;
    }

    public synchronized void setExerciseArchived(String id, boolean archived) {
        ContentValues values = new ContentValues();
        values.put("is_archived", archived ? 1 : 0);
        values.put("updated_at", System.currentTimeMillis());
        getWritableDatabase().update("exercise_definitions", values, "id=?", new String[] {id});
    }

    public synchronized boolean deleteCustomExerciseIfUnused(String id) {
        Models.ExerciseDefinition exercise = getExercise(id);
        if (exercise == null || !exercise.custom) return false;
        SQLiteDatabase db = getReadableDatabase();
        if (countWhere(db, "plan_exercises", "exercise_id=?", new String[] {id}) > 0) return false;
        if (countWhere(db, "exercise_records", "exercise_id=?", new String[] {id}) > 0) return false;
        getWritableDatabase().delete("exercise_definitions", "id=?", new String[] {id});
        return true;
    }

    public synchronized Models.Session createSession(Models.Plan plan) {
        if (plan == null || plan.exercises.isEmpty()) throw new IllegalArgumentException("训练计划中还没有动作");
        SQLiteDatabase db = getWritableDatabase();
        Models.Session session = new Models.Session();
        session.id = randomId();
        session.workoutPlanId = plan.id;
        session.planName = plan.name;
        session.startedAt = System.currentTimeMillis();
        session.playlistId = plan.assignedPlaylistId;
        Models.Playlist playlist = getPlaylist(plan.assignedPlaylistId);
        session.playlistName = playlist == null ? null : playlist.name;
        db.beginTransaction();
        try {
            insertSession(db, session);
            for (int exerciseIndex = 0; exerciseIndex < plan.exercises.size(); exerciseIndex++) {
                Models.PlannedExercise planned = plan.exercises.get(exerciseIndex);
                Models.ExerciseRecord record = new Models.ExerciseRecord();
                record.id = randomId();
                record.sessionId = session.id;
                record.exerciseId = planned.exerciseId;
                record.name = planned.name;
                record.sortOrder = exerciseIndex;
                record.restSeconds = Math.max(0, planned.restSeconds);
                record.notes = safe(planned.notes);
                insertRecord(db, record);
                int sets = Math.max(1, planned.targetSets);
                for (int number = 1; number <= sets; number++) {
                    Models.WorkoutSet set = new Models.WorkoutSet();
                    set.id = randomId();
                    set.recordId = record.id;
                    set.setNumber = number;
                    set.weight = Math.max(0, planned.targetWeight);
                    set.repetitions = Math.max(0, planned.targetRepetitions);
                    insertSet(db, set);
                }
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return getSession(session.id);
    }

    private void insertSession(SQLiteDatabase db, Models.Session session) {
        ContentValues row = new ContentValues();
        row.put("id", session.id);
        putNullable(row, "plan_id", session.workoutPlanId);
        row.put("plan_name", session.planName);
        row.put("started_at", session.startedAt);
        putNullable(row, "completed_at", session.completedAt);
        row.put("notes", safe(session.notes));
        row.put("status", session.status);
        row.put("current_exercise_index", session.currentExerciseIndex);
        row.put("current_set_number", session.currentSetNumber);
        putNullable(row, "playlist_id", session.playlistId);
        putNullable(row, "playlist_name", session.playlistName);
        db.insertOrThrow("sessions", null, row);
    }

    private void insertRecord(SQLiteDatabase db, Models.ExerciseRecord record) {
        ContentValues row = new ContentValues();
        row.put("id", record.id);
        row.put("session_id", record.sessionId);
        putNullable(row, "exercise_id", record.exerciseId);
        row.put("name_snapshot", record.name);
        row.put("sort_order", record.sortOrder);
        row.put("rest_seconds", record.restSeconds);
        row.put("notes", safe(record.notes));
        db.insertOrThrow("exercise_records", null, row);
    }

    private void insertSet(SQLiteDatabase db, Models.WorkoutSet set) {
        ContentValues row = new ContentValues();
        row.put("id", set.id);
        row.put("record_id", set.recordId);
        row.put("set_number", set.setNumber);
        row.put("weight", Math.max(0, set.weight));
        row.put("repetitions", Math.max(0, set.repetitions));
        row.put("is_completed", set.completed ? 1 : 0);
        putNullable(row, "completed_at", set.completedAt);
        row.put("is_warmup", set.warmup ? 1 : 0);
        db.insertOrThrow("set_records", null, row);
    }

    public synchronized Models.Session getActiveSession() {
        try (Cursor cursor = getReadableDatabase().query("sessions", new String[] {"id"}, "status='active'",
                null, null, null, "started_at DESC", "1")) {
            return cursor.moveToFirst() ? getSession(string(cursor, "id")) : null;
        }
    }

    public synchronized Models.Session getSession(String id) {
        if (id == null) return null;
        Models.Session session;
        try (Cursor cursor = getReadableDatabase().query("sessions", null, "id=?", new String[] {id},
                null, null, null)) {
            if (!cursor.moveToFirst()) return null;
            session = readSession(cursor);
        }
        try (Cursor cursor = getReadableDatabase().query("exercise_records", null, "session_id=?",
                new String[] {id}, null, null, "sort_order ASC")) {
            while (cursor.moveToNext()) {
                Models.ExerciseRecord record = new Models.ExerciseRecord();
                record.id = string(cursor, "id");
                record.sessionId = id;
                record.exerciseId = nullableString(cursor, "exercise_id");
                record.name = string(cursor, "name_snapshot");
                record.sortOrder = integer(cursor, "sort_order");
                record.restSeconds = integer(cursor, "rest_seconds");
                record.notes = string(cursor, "notes");
                loadSets(record);
                session.records.add(record);
            }
        }
        return session;
    }

    private Models.Session readSession(Cursor cursor) {
        Models.Session session = new Models.Session();
        session.id = string(cursor, "id");
        session.workoutPlanId = nullableString(cursor, "plan_id");
        session.planName = string(cursor, "plan_name");
        session.startedAt = number(cursor, "started_at");
        session.completedAt = nullableLong(cursor, "completed_at");
        session.notes = string(cursor, "notes");
        session.status = string(cursor, "status");
        session.currentExerciseIndex = integer(cursor, "current_exercise_index");
        session.currentSetNumber = integer(cursor, "current_set_number");
        session.playlistId = nullableString(cursor, "playlist_id");
        session.playlistName = nullableString(cursor, "playlist_name");
        return session;
    }

    private void loadSets(Models.ExerciseRecord record) {
        try (Cursor cursor = getReadableDatabase().query("set_records", null, "record_id=?",
                new String[] {record.id}, null, null, "set_number ASC")) {
            while (cursor.moveToNext()) {
                Models.WorkoutSet set = new Models.WorkoutSet();
                set.id = string(cursor, "id");
                set.recordId = record.id;
                set.setNumber = integer(cursor, "set_number");
                set.weight = real(cursor, "weight");
                set.repetitions = integer(cursor, "repetitions");
                set.completed = integer(cursor, "is_completed") != 0;
                set.completedAt = nullableLong(cursor, "completed_at");
                set.warmup = integer(cursor, "is_warmup") != 0;
                record.sets.add(set);
            }
        }
    }

    public synchronized void updateSet(Models.WorkoutSet set) {
        ContentValues row = new ContentValues();
        row.put("weight", Math.max(0, set.weight));
        row.put("repetitions", Math.max(0, set.repetitions));
        row.put("is_completed", set.completed ? 1 : 0);
        putNullable(row, "completed_at", set.completedAt);
        row.put("is_warmup", set.warmup ? 1 : 0);
        getWritableDatabase().update("set_records", row, "id=?", new String[] {set.id});
    }

    public synchronized Models.WorkoutSet addSet(String recordId) {
        Models.ExerciseRecord record = getRecord(recordId);
        if (record == null) return null;
        Models.WorkoutSet set = new Models.WorkoutSet();
        set.id = randomId();
        set.recordId = recordId;
        set.setNumber = record.sets.size() + 1;
        if (!record.sets.isEmpty()) {
            Models.WorkoutSet previous = record.sets.get(record.sets.size() - 1);
            set.weight = previous.weight;
            set.repetitions = previous.repetitions;
        }
        insertSet(getWritableDatabase(), set);
        return set;
    }

    public synchronized boolean removeLastSet(String recordId) {
        Models.ExerciseRecord record = getRecord(recordId);
        if (record == null || record.sets.size() <= 1) return false;
        Models.WorkoutSet last = record.sets.get(record.sets.size() - 1);
        return getWritableDatabase().delete("set_records", "id=?", new String[] {last.id}) > 0;
    }

    private Models.ExerciseRecord getRecord(String recordId) {
        try (Cursor cursor = getReadableDatabase().query("exercise_records", null, "id=?",
                new String[] {recordId}, null, null, null)) {
            if (!cursor.moveToFirst()) return null;
            Models.ExerciseRecord record = new Models.ExerciseRecord();
            record.id = recordId;
            record.sessionId = string(cursor, "session_id");
            record.exerciseId = nullableString(cursor, "exercise_id");
            record.name = string(cursor, "name_snapshot");
            record.sortOrder = integer(cursor, "sort_order");
            record.restSeconds = integer(cursor, "rest_seconds");
            record.notes = string(cursor, "notes");
            loadSets(record);
            return record;
        }
    }

    public synchronized void updateRecordNotes(String recordId, String notes) {
        ContentValues row = new ContentValues();
        row.put("notes", safe(notes));
        getWritableDatabase().update("exercise_records", row, "id=?", new String[] {recordId});
    }

    public synchronized void updateSessionCursor(String id, int exerciseIndex, int setNumber) {
        ContentValues row = new ContentValues();
        row.put("current_exercise_index", Math.max(0, exerciseIndex));
        row.put("current_set_number", Math.max(1, setNumber));
        getWritableDatabase().update("sessions", row, "id=?", new String[] {id});
    }

    public synchronized void finishSession(String id, String notes) {
        ContentValues row = new ContentValues();
        row.put("status", "completed");
        row.put("completed_at", System.currentTimeMillis());
        row.put("notes", safe(notes));
        getWritableDatabase().update("sessions", row, "id=? AND status='active'", new String[] {id});
    }

    public synchronized void updateSessionNotes(String id, String notes) {
        ContentValues row = new ContentValues();
        row.put("notes", safe(notes));
        getWritableDatabase().update("sessions", row, "id=?", new String[] {id});
    }

    public synchronized void cancelSession(String id) {
        ContentValues row = new ContentValues();
        row.put("status", "cancelled");
        row.put("completed_at", System.currentTimeMillis());
        getWritableDatabase().update("sessions", row, "id=? AND status='active'", new String[] {id});
    }

    public synchronized List<Models.Session> getCompletedSessions(String search) {
        List<Models.Session> values = new ArrayList<>();
        String query = normalize(search);
        try (Cursor cursor = getReadableDatabase().query("sessions", new String[] {"id"}, "status='completed'",
                null, null, null, "started_at DESC")) {
            while (cursor.moveToNext()) {
                Models.Session session = getSession(string(cursor, "id"));
                if (query.isEmpty() || normalize(session.planName).contains(query) || sessionContains(session, query)) {
                    values.add(session);
                }
            }
        }
        return values;
    }

    private boolean sessionContains(Models.Session session, String query) {
        for (Models.ExerciseRecord record : session.records) {
            if (normalize(record.name).contains(query)) return true;
        }
        return false;
    }

    public synchronized Models.Session getLastCompletedForPlan(String planId) {
        if (planId == null) return null;
        try (Cursor cursor = getReadableDatabase().query("sessions", new String[] {"id"},
                "status='completed' AND plan_id=?", new String[] {planId}, null, null, "completed_at DESC", "1")) {
            return cursor.moveToFirst() ? getSession(string(cursor, "id")) : null;
        }
    }

    public synchronized void deleteSession(String id) {
        getWritableDatabase().delete("sessions", "id=?", new String[] {id});
    }

    public synchronized List<Models.Track> getTracks() {
        List<Models.Track> values = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().query("tracks", null, null, null, null, null,
                "sort_order ASC, created_at ASC")) {
            while (cursor.moveToNext()) values.add(readTrack(cursor));
        }
        return values;
    }

    public synchronized Models.Track getTrack(String id) {
        if (id == null) return null;
        try (Cursor cursor = getReadableDatabase().query("tracks", null, "id=?", new String[] {id},
                null, null, null)) {
            return cursor.moveToFirst() ? readTrack(cursor) : null;
        }
    }

    private Models.Track readTrack(Cursor cursor) {
        Models.Track track = new Models.Track();
        track.id = string(cursor, "id");
        track.title = string(cursor, "title");
        track.artist = string(cursor, "artist");
        track.storedFileName = string(cursor, "stored_filename");
        track.originalFileName = string(cursor, "original_filename");
        track.extension = string(cursor, "extension");
        track.durationMs = number(cursor, "duration_ms");
        track.createdAt = number(cursor, "created_at");
        track.sortOrder = integer(cursor, "sort_order");
        return track;
    }

    public synchronized Models.Track saveTrack(Models.Track track) {
        if (track.id == null) track.id = randomId();
        if (track.createdAt == 0) track.createdAt = System.currentTimeMillis();
        if (track.sortOrder < 0) track.sortOrder = getTracks().size();
        ContentValues row = new ContentValues();
        row.put("id", track.id);
        row.put("title", safeDefault(track.title, "未命名音频"));
        row.put("artist", safe(track.artist));
        row.put("stored_filename", track.storedFileName);
        row.put("original_filename", track.originalFileName);
        row.put("extension", safe(track.extension));
        row.put("duration_ms", Math.max(0, track.durationMs));
        row.put("created_at", track.createdAt);
        row.put("sort_order", track.sortOrder);
        getWritableDatabase().insertOrThrow("tracks", null, row);
        return track;
    }

    public synchronized void deleteTrack(String id) {
        getWritableDatabase().delete("tracks", "id=?", new String[] {id});
    }

    public synchronized void updateTrackSortOrders(List<String> trackIds) {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            for (int index = 0; index < trackIds.size(); index++) {
                ContentValues row = new ContentValues();
                row.put("sort_order", index);
                db.update("tracks", row, "id=?", new String[] {trackIds.get(index)});
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    public synchronized List<Models.Playlist> getPlaylists() {
        List<Models.Playlist> values = new ArrayList<>();
        try (Cursor cursor = getReadableDatabase().query("playlists", null, null, null, null, null,
                "sort_order ASC, created_at ASC")) {
            while (cursor.moveToNext()) {
                Models.Playlist value = readPlaylist(cursor);
                loadPlaylistTracks(value);
                values.add(value);
            }
        }
        return values;
    }

    public synchronized Models.Playlist getPlaylist(String id) {
        if (id == null) return null;
        try (Cursor cursor = getReadableDatabase().query("playlists", null, "id=?", new String[] {id},
                null, null, null)) {
            if (!cursor.moveToFirst()) return null;
            Models.Playlist value = readPlaylist(cursor);
            loadPlaylistTracks(value);
            return value;
        }
    }

    private Models.Playlist readPlaylist(Cursor cursor) {
        Models.Playlist value = new Models.Playlist();
        value.id = string(cursor, "id");
        value.name = string(cursor, "name");
        value.createdAt = number(cursor, "created_at");
        value.updatedAt = number(cursor, "updated_at");
        value.sortOrder = integer(cursor, "sort_order");
        return value;
    }

    private void loadPlaylistTracks(Models.Playlist playlist) {
        try (Cursor cursor = getReadableDatabase().query("playlist_tracks", new String[] {"track_id"},
                "playlist_id=?", new String[] {playlist.id}, null, null, "sort_order ASC")) {
            while (cursor.moveToNext()) playlist.trackIds.add(string(cursor, "track_id"));
        }
    }

    public synchronized Models.Playlist savePlaylist(Models.Playlist playlist) {
        String name = playlist.name == null ? "" : playlist.name.trim();
        if (name.isEmpty()) throw new IllegalArgumentException("播放列表名称不能为空");
        SQLiteDatabase db = getWritableDatabase();
        long now = System.currentTimeMillis();
        if (playlist.id == null) {
            playlist.id = randomId();
            playlist.createdAt = now;
            playlist.sortOrder = getPlaylists().size();
        }
        playlist.name = name;
        playlist.updatedAt = now;
        db.beginTransaction();
        try {
            ContentValues row = new ContentValues();
            row.put("name", playlist.name);
            row.put("created_at", playlist.createdAt);
            row.put("updated_at", playlist.updatedAt);
            row.put("sort_order", playlist.sortOrder);
            if (db.update("playlists", row, "id=?", new String[] {playlist.id}) == 0) {
                row.put("id", playlist.id);
                db.insertOrThrow("playlists", null, row);
            }
            db.delete("playlist_tracks", "playlist_id=?", new String[] {playlist.id});
            for (int index = 0; index < playlist.trackIds.size(); index++) {
                ContentValues link = new ContentValues();
                link.put("playlist_id", playlist.id);
                link.put("track_id", playlist.trackIds.get(index));
                link.put("sort_order", index);
                db.insertOrThrow("playlist_tracks", null, link);
            }
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
        return playlist;
    }

    public synchronized void deletePlaylist(String id) {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete("playlists", "id=?", new String[] {id});
            ContentValues clear = new ContentValues();
            clear.putNull("playlist_id");
            db.update("plans", clear, "playlist_id=?", new String[] {id});
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    public synchronized void resetSamplePlansAndExercises() {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete("plans", null, null);
            db.delete("exercise_definitions", null, null);
            seedExercises(db);
            seedPlans(db);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    public synchronized void deleteAllWorkoutData() {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete("sessions", null, null);
            db.delete("plans", null, null);
            db.delete("exercise_definitions", null, null);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    public synchronized void deleteAllAudioRecords() {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete("playlists", null, null);
            db.delete("tracks", null, null);
            ContentValues clear = new ContentValues();
            clear.putNull("playlist_id");
            db.update("plans", clear, null, null);
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    private static long count(SQLiteDatabase db, String table) {
        return countWhere(db, table, null, null);
    }

    private static long countWhere(SQLiteDatabase db, String table, String selection, String[] args) {
        try (Cursor cursor = db.query(table, new String[] {"COUNT(*)"}, selection, args, null, null, null)) {
            return cursor.moveToFirst() ? cursor.getLong(0) : 0;
        }
    }

    public static String normalize(String value) {
        if (value == null) return "";
        String decomposed = Normalizer.normalize(value.trim(), Normalizer.Form.NFD);
        return decomposed.replaceAll("\\p{M}+", "").toLowerCase(Locale.ROOT);
    }

    private static String randomId() { return UUID.randomUUID().toString(); }

    private static String stableId(String value) {
        return UUID.nameUUIDFromBytes(value.getBytes(StandardCharsets.UTF_8)).toString();
    }

    private static String safe(String value) { return value == null ? "" : value; }

    private static String safeDefault(String value, String fallback) {
        return value == null || value.trim().isEmpty() ? fallback : value.trim();
    }

    private static void putNullable(ContentValues values, String key, String value) {
        if (value == null) values.putNull(key); else values.put(key, value);
    }

    private static void putNullable(ContentValues values, String key, Integer value) {
        if (value == null) values.putNull(key); else values.put(key, value);
    }

    private static void putNullable(ContentValues values, String key, Long value) {
        if (value == null) values.putNull(key); else values.put(key, value);
    }

    private static String string(Cursor cursor, String column) {
        int index = cursor.getColumnIndexOrThrow(column);
        String value = cursor.getString(index);
        return value == null ? "" : value;
    }

    private static String nullableString(Cursor cursor, String column) {
        int index = cursor.getColumnIndexOrThrow(column);
        return cursor.isNull(index) ? null : cursor.getString(index);
    }

    private static int integer(Cursor cursor, String column) {
        return cursor.getInt(cursor.getColumnIndexOrThrow(column));
    }

    private static Integer nullableInteger(Cursor cursor, String column) {
        int index = cursor.getColumnIndexOrThrow(column);
        return cursor.isNull(index) ? null : cursor.getInt(index);
    }

    private static long number(Cursor cursor, String column) {
        return cursor.getLong(cursor.getColumnIndexOrThrow(column));
    }

    private static Long nullableLong(Cursor cursor, String column) {
        int index = cursor.getColumnIndexOrThrow(column);
        return cursor.isNull(index) ? null : cursor.getLong(index);
    }

    private static double real(Cursor cursor, String column) {
        return cursor.getDouble(cursor.getColumnIndexOrThrow(column));
    }
}
