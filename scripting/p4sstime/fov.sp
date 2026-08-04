// Client FOV management with cookie persistence and Steam-down backup

void SetFOV(int client, int fov) {
  SetEntProp(client, Prop_Send, "m_iFOV", fov);
  SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
}

bool GetFOVCookie(int client) {
  char cookie[4];
  GetClientCookie(client, ck_iFov, cookie, sizeof(cookie));
  int fov = StringToInt(cookie);
  int minFov = cvFovMin.IntValue;
  int maxFov = cvFovMax.IntValue;

  if (fov < minFov || fov > maxFov) return false;

  if (g_bBackupFOVDB) {
    g_iPlayerFOV[client] = fov;
    g_bPlayerTracked[client] = true;
  }

  SetFOV(client, fov);
  return true;
}

void SetBackupSystem(bool enable) {
  if (g_bBackupFOVDB == enable) return;
  g_bBackupFOVDB = enable;

  for (int i = 1; i <= MaxClients; i++) {
    g_iPlayerFOV[i] = 0;
    g_bPlayerTracked[i] = false;
  }

  if (enable) PrintToServer("[p4sstime] Backup FOV system enabled - Steam connection is down");
  else        PrintToServer("[p4sstime] Backup FOV system disabled - Steam connection restored");
}

void RestoreFOV(int client) {
  if (AreClientCookiesCached(client)) {
    if (GetFOVCookie(client)) {
      if (!g_bSteamOnline) {
        g_bSteamOnline = true;
        if (g_bBackupFOVDB) SetBackupSystem(false);
      }
      return;
    }
  }
  elif (!g_bBackupFOVDB) {
    SetBackupSystem(true);
    g_bSteamOnline = false;
  }

  if (g_bBackupFOVDB && g_bPlayerTracked[client] && g_iPlayerFOV[client] > 0)
    SetFOV(client, g_iPlayerFOV[client]);
}

void ClearFOVClientState(int client) {
  if (g_bBackupFOVDB) {
    g_bPlayerTracked[client] = false;
    g_iPlayerFOV[client] = 0;
  }
}

public void OnFOVQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] fov) {
  if (result != ConVarQuery_Okay) return;
  SetClientCookie(client, ck_iFov, "");
  SetFOV(client, StringToInt(fov));
}

Action CSetFOV(int client, int args) {
  if (args != 1) {
    CTagReply(client, "Usage: sm_pt_fov <fov>");
    return Plugin_Handled;
  }

  int fov = GetCmdArgInt(1);
  int minFov = cvFovMin.IntValue;
  int maxFov = cvFovMax.IntValue;

  if (fov == 0) {
    QueryClientConVar(client, "fov_desired", OnFOVQueried);
    CTagReply(client, "Your FOV has been reset.");
    return Plugin_Handled;
  }

  if (fov < minFov) {
    CTagReply(client, "The minimum FOV you can set is %d.", minFov);
    return Plugin_Handled;
  }
  if (fov > maxFov) {
    CTagReply(client, "The maximum FOV you can set is %d.", maxFov);
    return Plugin_Handled;
  }

  bool cookieSuccess = false;
  if (AreClientCookiesCached(client)) {
    char sCookie[4];
    IntToString(fov, sCookie, sizeof(sCookie));
    SetClientCookie(client, ck_iFov, sCookie);
    cookieSuccess = true;
    g_bSteamOnline = true;

    if (g_bBackupFOVDB) SetBackupSystem(false);
  } else {
    if (!g_bBackupFOVDB) SetBackupSystem(true);
    g_bSteamOnline = false;

    g_iPlayerFOV[client] = fov;
    g_bPlayerTracked[client] = true;
  }

  SetFOV(client, fov);

  CTagReply(client, "Your FOV has been set to %d.%s", fov, cookieSuccess ? "" : " (Steam is down, this will be reset on leaving.)");
  return Plugin_Handled;
}

public void OnSpecFOVQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] fov) {
  if (result != ConVarQuery_Okay) return;
  SetFOV(client, StringToInt(fov));
}

void GetSpecFOVCookie(int client) {
  char cookie[4];
  GetClientCookie(client, ck_iSpecFov, cookie, sizeof(cookie));
  int fov = StringToInt(cookie);
  int minFov = cvFovMin.IntValue;
  int maxFov = cvFovMax.IntValue;
  if (fov != 0 && (fov < minFov || fov > maxFov)) fov = 0;
  g_iPlySpecFov[client] = fov;
}

void ApplySpecFov(int client) {
  int fov = g_iPlySpecFov[client];
  if (fov <= 0) return;

  int minFov = cvFovMin.IntValue;
  int maxFov = cvFovMax.IntValue;
  if (fov < minFov || fov > maxFov) return;

  SetFOV(client, fov);
}

Action CSetSpecFOV(int client, int args) {
  if (args != 1) {
    CTagReply(client, "Usage: sm_spec_fov <fov>");
    return Plugin_Handled;
  }

  int fov = GetCmdArgInt(1);
  int minFov = cvFovMin.IntValue;
  int maxFov = cvFovMax.IntValue;

  if (fov <= 0) {
    g_iPlySpecFov[client] = 0;
    SetClientCookie(client, ck_iSpecFov, "0");
    QueryClientConVar(client, "fov_desired", OnSpecFOVQueried);
    CTagReply(client, "Your spectator FOV has been reset.");
    return Plugin_Handled;
  }

  if (fov < minFov) {
    CTagReply(client, "The minimum FOV you can set is %d.", minFov);
    return Plugin_Handled;
  }
  if (fov > maxFov) {
    CTagReply(client, "The maximum FOV you can set is %d.", maxFov);
    return Plugin_Handled;
  }

  g_iPlySpecFov[client] = fov;
  char sCookie[4];
  IntToString(fov, sCookie, sizeof(sCookie));
  SetClientCookie(client, ck_iSpecFov, sCookie);

  if (TF2_GetClientTeam(client) == TFTeam_Spectator) {
    ApplySpecFov(client);
  }

  CTagReply(client, "Your spectator FOV has been set to %d.", fov);
  return Plugin_Handled;
}

Action Timer_ApplySpecFov(Handle timer, any client) {
  ApplySpecFov(client);
  return Plugin_Stop;
}

Action OnSpecCommand(int client, const char[] command, int argc) {
  if (g_iPlySpecFov[client] == 0) return Plugin_Continue;
  if (TF2_GetClientTeam(client) != TFTeam_Spectator) return Plugin_Continue;
  CreateTimer(0.0, Timer_ApplySpecFov, client, TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

Action Timer_CheckSpecFov(Handle timer) {
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsClientInGame(i)) continue;
    if (TF2_GetClientTeam(i) != TFTeam_Spectator) continue;
    if (g_iPlySpecFov[i] == 0) continue;

    int mode = GetEntProp(i, Prop_Send, "m_iObserverMode");
    int target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

    if (mode != g_iPlyObserverMode[i] || target != g_iPlyObserverTarget[i]) {
      ApplySpecFov(i);
      g_iPlyObserverMode[i] = mode;
      g_iPlyObserverTarget[i] = target;
    }
  }
  return Plugin_Continue;
}
