// This file relates to all features for practice mode and will contain the functions for them
v Hook_OnPracticeModeChange(CV convar, const c[] oldValue, const c[] newValue) {
  if (bPractice.BoolValue) {
    int entityTimer = FindEntityByClassname(-1, "team_round_timer");
    SetVariantInt(300);
    AcceptEntityInput(entityTimer, "AddTime");
    CreateTimer(300.0, AddFiveMinutes, _, TIMER_REPEAT);  // 5 minutes
  }
}

Action AddFiveMinutes(Han timer) {
  if (bPractice.BoolValue) {
    int entityTimer = FindEntityByClassname(-1, "team_round_timer");
    SetVariantInt(300);
    AcceptEntityInput(entityTimer, "AddTime");
    PC;
  }
  else PS;
}