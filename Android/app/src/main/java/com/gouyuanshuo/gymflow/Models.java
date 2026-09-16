package com.gouyuanshuo.gymflow;

import java.util.ArrayList;
import java.util.List;

public final class Models {
    private Models() {}

    public static final class ExerciseDefinition {
        public String id;
        public String name;
        public String muscleGroup = "其他";
        public String secondaryMuscleGroups = "";
        public String equipment = "其他";
        public Integer defaultRestSeconds;
        public Integer defaultSets;
        public Integer defaultRepetitions;
        public String notes = "";
        public boolean custom;
        public boolean archived;
        public long createdAt;
        public long updatedAt;

        @Override public String toString() { return name; }
    }

    public static final class PlannedExercise {
        public String id;
        public String exerciseId;
        public String name;
        public int targetSets = 3;
        public int targetRepetitions = 10;
        public double targetWeight;
        public int restSeconds = 90;
        public String notes = "";
        public int sortOrder;

        public PlannedExercise copy() {
            PlannedExercise value = new PlannedExercise();
            value.id = id;
            value.exerciseId = exerciseId;
            value.name = name;
            value.targetSets = targetSets;
            value.targetRepetitions = targetRepetitions;
            value.targetWeight = targetWeight;
            value.restSeconds = restSeconds;
            value.notes = notes;
            value.sortOrder = sortOrder;
            return value;
        }
    }

    public static final class Plan {
        public String id;
        public String name;
        public String notes = "";
        public long createdAt;
        public long updatedAt;
        public int sortOrder;
        public String assignedPlaylistId;
        public final List<PlannedExercise> exercises = new ArrayList<>();

        public Plan copy() {
            Plan value = new Plan();
            value.id = id;
            value.name = name;
            value.notes = notes;
            value.createdAt = createdAt;
            value.updatedAt = updatedAt;
            value.sortOrder = sortOrder;
            value.assignedPlaylistId = assignedPlaylistId;
            for (PlannedExercise exercise : exercises) value.exercises.add(exercise.copy());
            return value;
        }

        @Override public String toString() { return name; }
    }

    public static final class WorkoutSet {
        public String id;
        public String recordId;
        public int setNumber;
        public double weight;
        public int repetitions;
        public boolean completed;
        public Long completedAt;
        public boolean warmup;
    }

    public static final class ExerciseRecord {
        public String id;
        public String sessionId;
        public String exerciseId;
        public String name;
        public int sortOrder;
        public int restSeconds;
        public String notes = "";
        public final List<WorkoutSet> sets = new ArrayList<>();
    }

    public static final class Session {
        public String id;
        public String workoutPlanId;
        public String planName;
        public long startedAt;
        public Long completedAt;
        public String notes = "";
        public String status = "active";
        public int currentExerciseIndex;
        public int currentSetNumber = 1;
        public String playlistId;
        public String playlistName;
        public final List<ExerciseRecord> records = new ArrayList<>();
    }

    public static final class Track {
        public String id;
        public String title;
        public String artist = "";
        public String storedFileName;
        public String originalFileName;
        public String extension;
        public long durationMs;
        public long createdAt;
        public int sortOrder;

        @Override public String toString() { return title; }
    }

    public static final class Playlist {
        public String id;
        public String name;
        public long createdAt;
        public long updatedAt;
        public int sortOrder;
        public final List<String> trackIds = new ArrayList<>();

        @Override public String toString() { return name; }
    }
}
