package com.gouyuanshuo.gymflow;

import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class WorkoutMathTest {
    @Test public void totalsOnlyCountCompletedSets() {
        Models.Session session = new Models.Session();
        Models.ExerciseRecord record = new Models.ExerciseRecord();
        Models.WorkoutSet completed = new Models.WorkoutSet();
        completed.completed = true;
        completed.weight = 60;
        completed.repetitions = 8;
        Models.WorkoutSet pending = new Models.WorkoutSet();
        pending.weight = 100;
        pending.repetitions = 10;
        record.sets.add(completed);
        record.sets.add(pending);
        session.records.add(record);

        WorkoutMath.Totals totals = WorkoutMath.totals(session);
        assertEquals(1, totals.exercises);
        assertEquals(1, totals.sets);
        assertEquals(8, totals.repetitions);
        assertEquals(480, totals.volume, 0.001);
    }

    @Test public void durationCountsRestBetweenSetsOnly() {
        Models.Plan plan = new Models.Plan();
        Models.PlannedExercise exercise = new Models.PlannedExercise();
        exercise.targetSets = 4;
        exercise.restSeconds = 180;
        plan.exercises.add(exercise);
        assertEquals(12, WorkoutMath.expectedDurationMinutes(plan));
    }

    @Test public void epleyEstimateUsesSupportedRepRange() {
        assertEquals(100, WorkoutMath.estimatedOneRepMax(75, 10), 0.001);
        assertEquals(0, WorkoutMath.estimatedOneRepMax(75, 16), 0.001);
        assertEquals(0, WorkoutMath.estimatedOneRepMax(0, 10), 0.001);
    }
}
