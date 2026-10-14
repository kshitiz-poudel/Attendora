/// Attendance policy shared by the teacher and student portals.
///
/// A student whose attendance in a subject falls below this percentage is
/// flagged "at risk" on their own dashboard, and a teacher is offered the
/// Detain action for them. Keeping it in one place stops the two portals
/// drifting apart (the teacher side used 60% while the student side warned at
/// 75%, so a student could be told they were at risk without the teacher ever
/// being offered the button).
const double kMinAttendancePercent = 75.0;

/// A subject needs at least this many held sessions before a percentage means
/// anything. Without it, a teacher who has run zero or one session would see
/// every student at 0% and be offered "Detain" for all of them.
const int kMinSessionsForDetention = 1;
