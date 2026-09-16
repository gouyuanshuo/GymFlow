package com.gouyuanshuo.gymflow;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public final class WorkoutAnalytics {
    private WorkoutAnalytics() {}

    public static final class PersonalBests {
        public double heaviestWeight;
        public double estimatedOneRepMax;
        public double setVolume;
        public int repetitions;
        public double repetitionWeight;
        public final List<String> events = new ArrayList<>();

        public boolean hasAny() {
            return heaviestWeight > 0 || estimatedOneRepMax > 0 || setVolume > 0 || repetitions > 0;
        }
    }

    public static final class Highlight {
        public String name;
        public int sets;
        public int repetitions;
        public double volume;
    }

    public static PersonalBests personalBests(String exerciseId, String exerciseName,
                                               List<Models.Session> sessions) {
        PersonalBests bests = new PersonalBests();
        double relevantWeight = 0;
        List<Models.Session> chronological = new ArrayList<>(sessions);
        chronological.sort(Comparator.comparingLong(value -> value.startedAt));
        double runningWeight = 0;
        double runningOneRepMax = 0;
        double runningVolume = 0;
        int runningReps = 0;
        for (Models.Session session : chronological) {
            if (!"completed".equals(session.status)) continue;
            for (Models.ExerciseRecord record : session.records) {
                if (!matches(exerciseId, exerciseName, record)) continue;
                for (Models.WorkoutSet set : record.sets) {
                    if (!set.completed || set.warmup) continue;
                    double weight = Math.max(0, set.weight);
                    int reps = Math.max(0, set.repetitions);
                    double estimate = WorkoutMath.estimatedOneRepMax(weight, reps);
                    double volume = weight * reps;
                    if (weight > runningWeight + 0.0001) {
                        runningWeight = weight;
                        bests.events.add(record.name + " · 最重重量 " + WorkoutMath.formatWeight(weight) + " 千克");
                    }
                    if (estimate > runningOneRepMax + 0.0001) {
                        runningOneRepMax = estimate;
                        bests.events.add(record.name + " · 预估 1RM " + WorkoutMath.formatWeight(estimate) + " 千克");
                    }
                    if (volume > runningVolume + 0.0001) {
                        runningVolume = volume;
                        bests.events.add(record.name + " · 单组容量 " + WorkoutMath.formatWeight(volume) + " 千克");
                    }
                    if (weight == 0 && reps > runningReps) {
                        runningReps = reps;
                        relevantWeight = 0;
                    } else if (weight >= runningWeight * 0.5 && reps > runningReps) {
                        runningReps = reps;
                        relevantWeight = weight;
                    }
                }
            }
        }
        bests.heaviestWeight = runningWeight;
        bests.estimatedOneRepMax = runningOneRepMax;
        bests.setVolume = runningVolume;
        bests.repetitions = runningReps;
        bests.repetitionWeight = relevantWeight;
        return bests;
    }

    private static boolean matches(String exerciseId, String exerciseName, Models.ExerciseRecord record) {
        if (exerciseId != null && record.exerciseId != null) return exerciseId.equals(record.exerciseId);
        return GymFlowDatabase.normalize(exerciseName).equals(GymFlowDatabase.normalize(record.name));
    }

    public static List<Highlight> highlights(Models.Session session) {
        List<Highlight> values = new ArrayList<>();
        for (Models.ExerciseRecord record : session.records) {
            Highlight value = new Highlight();
            value.name = record.name;
            for (Models.WorkoutSet set : record.sets) {
                if (!set.completed) continue;
                value.sets++;
                value.repetitions += Math.max(0, set.repetitions);
                value.volume += Math.max(0, set.weight) * Math.max(0, set.repetitions);
            }
            if (value.sets > 0) values.add(value);
        }
        values.sort((left, right) -> {
            int volume = Double.compare(right.volume, left.volume);
            if (volume != 0) return volume;
            int sets = Integer.compare(right.sets, left.sets);
            return sets != 0 ? sets : left.name.compareTo(right.name);
        });
        return values.size() <= 3 ? values : new ArrayList<>(values.subList(0, 3));
    }

    public static String newestPersonalBest(Models.Session target, List<Models.Session> allSessions) {
        for (Models.ExerciseRecord record : target.records) {
            PersonalBests before = personalBests(record.exerciseId, record.name,
                    sessionsBefore(allSessions, target.startedAt));
            for (Models.WorkoutSet set : record.sets) {
                if (!set.completed || set.warmup) continue;
                if (set.weight > before.heaviestWeight + 0.0001) {
                    return record.name + " · 重量新纪录 " + WorkoutMath.formatWeight(set.weight) + " 千克";
                }
                double estimate = WorkoutMath.estimatedOneRepMax(set.weight, set.repetitions);
                if (estimate > before.estimatedOneRepMax + 0.0001) {
                    return record.name + " · 预估 1RM 新纪录 " + WorkoutMath.formatWeight(estimate) + " 千克";
                }
            }
        }
        return null;
    }

    private static List<Models.Session> sessionsBefore(List<Models.Session> values, long time) {
        List<Models.Session> result = new ArrayList<>();
        for (Models.Session value : values) if (value.startedAt < time) result.add(value);
        return result;
    }
}
