package com.gouyuanshuo.gymflow;

import java.util.Locale;

public final class WorkoutMath {
    private WorkoutMath() {}

    public static final class Totals {
        public int exercises;
        public int sets;
        public int repetitions;
        public double volume;
    }

    public static Totals totals(Models.Session session) {
        Totals totals = new Totals();
        for (Models.ExerciseRecord record : session.records) {
            boolean hasCompleted = false;
            for (Models.WorkoutSet set : record.sets) {
                if (!set.completed) continue;
                hasCompleted = true;
                totals.sets++;
                totals.repetitions += Math.max(0, set.repetitions);
                totals.volume += Math.max(0, set.weight) * Math.max(0, set.repetitions);
            }
            if (hasCompleted) totals.exercises++;
        }
        return totals;
    }

    public static int expectedDurationMinutes(Models.Plan plan) {
        long seconds = 0;
        for (Models.PlannedExercise exercise : plan.exercises) {
            int sets = Math.max(1, exercise.targetSets);
            seconds += sets * 45L + Math.max(0, sets - 1) * Math.max(0, exercise.restSeconds);
        }
        return Math.max(1, (int) Math.ceil(seconds / 60.0));
    }

    public static double estimatedOneRepMax(double weight, int repetitions) {
        if (weight <= 0 || repetitions < 1 || repetitions > 15) return 0;
        return weight * (1.0 + repetitions / 30.0);
    }

    public static String formatWeight(double value) {
        if (Math.abs(value - Math.rint(value)) < 0.0001) {
            return String.format(Locale.CHINA, "%.0f", value);
        }
        return String.format(Locale.CHINA, "%.1f", value);
    }

    public static String formatDuration(long seconds) {
        long safe = Math.max(0, seconds);
        long hours = safe / 3600;
        long minutes = (safe % 3600) / 60;
        long remaining = safe % 60;
        if (hours > 0) return String.format(Locale.CHINA, "%d:%02d:%02d", hours, minutes, remaining);
        return String.format(Locale.CHINA, "%02d:%02d", minutes, remaining);
    }
}
