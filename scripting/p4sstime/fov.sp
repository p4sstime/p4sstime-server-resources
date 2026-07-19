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
