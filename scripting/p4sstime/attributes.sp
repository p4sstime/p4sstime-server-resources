// Inline TF2 attribute manipulation via SDKCalls
// Replaces the tf2attributes plugin dependency

Handle hSDKSchema;
Handle hSDKGetAttributeDefByName;
Handle hSDKSetRuntimeValue;
Handle hSDKRemoveAttribute;
StringMap g_AttributeDefCache;

void InitAttributeSDKCalls() {
  StartPrepSDKCall(SDKCall_Static);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "GEconItemSchema");
  PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
  hSDKSchema = EndPrepSDKCall();
  if (hSDKSchema == null)
    SetFailState("Failed to find GEconItemSchema");

  StartPrepSDKCall(SDKCall_Raw);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
  PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
  PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
  hSDKGetAttributeDefByName = EndPrepSDKCall();
  if (hSDKGetAttributeDefByName == null)
    SetFailState("Failed to find CEconItemSchema::GetAttributeDefinitionByName");

  StartPrepSDKCall(SDKCall_Raw);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CAttributeList::SetRuntimeAttributeValue");
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
  hSDKSetRuntimeValue = EndPrepSDKCall();
  if (hSDKSetRuntimeValue == null)
    SetFailState("Failed to find CAttributeList::SetRuntimeAttributeValue");

  StartPrepSDKCall(SDKCall_Raw);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CAttributeList::RemoveAttribute");
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
  hSDKRemoveAttribute = EndPrepSDKCall();
  if (hSDKRemoveAttribute == null)
    SetFailState("Failed to find CAttributeList::RemoveAttribute");

  g_AttributeDefCache = new StringMap();
}

void ClearAttributeDefCache() {
  if (g_AttributeDefCache != null)
    g_AttributeDefCache.Clear();
}

static Address GetItemSchema() {
  return SDKCall(hSDKSchema);
}

static Address GetEntityAttributeList(int entity) {
  int offs = GetEntSendPropOffs(entity, "m_AttributeList", true);
  if (offs > 0)
    return GetEntityAddress(entity) + view_as<Address>(offs);
  return Address_Null;
}

static Address GetAttributeDefinitionByName(const char[] name) {
  Address cached;
  if (g_AttributeDefCache.GetValue(name, cached))
    return cached;

  Address pSchema = GetItemSchema();
  if (!pSchema) return Address_Null;

  cached = SDKCall(hSDKGetAttributeDefByName, pSchema, name);
  g_AttributeDefCache.SetValue(name, cached);
  return cached;
}

bool SetAttributeByName(int entity, const char[] name, float value) {
  if (!IsValidEntity(entity)) return false;

  Address pList = GetEntityAttributeList(entity);
  if (!pList) return false;

  Address pDef = GetAttributeDefinitionByName(name);
  if (!pDef) return false;

  SDKCall(hSDKSetRuntimeValue, pList, pDef, value);
  return true;
}

bool RemoveAttributeByName(int entity, const char[] name) {
  if (!IsValidEntity(entity)) return false;

  Address pList = GetEntityAttributeList(entity);
  if (!pList) return false;

  Address pDef = GetAttributeDefinitionByName(name);
  if (!pDef) return false;

  SDKCall(hSDKRemoveAttribute, pList, pDef);
  return true;
}
