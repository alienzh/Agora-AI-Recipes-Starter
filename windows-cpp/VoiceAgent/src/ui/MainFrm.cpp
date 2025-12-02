// MainFrm.cpp - Direct SDK management (like macOS ViewController)

#include "../general/pch.h"
#include "../general/framework.h"
#include "../general/VoiceAgent.h"
#include "MainFrm.h"
#include "../../resources/Resource.h"
#include "../KeyCenter.h"
#include "../tools/Logger.h"
#include "../tools/StringUtils.h"
#include "../api/TokenGenerator.h"
#include "../api/AgentManager.h"
#include <ctime>

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

// Message IDs
#define WM_TOKEN_FAILED       (WM_USER + 1)
#define WM_RTM_LOGIN_SUCCESS  (WM_USER + 2)
#define WM_RTM_LOGIN_FAILED   (WM_USER + 3)
#define WM_AGENT_STARTED      (WM_USER + 4)
#define WM_AGENT_START_FAILED (WM_USER + 5)
#define WM_AGENT_JOINED       (WM_USER + 6)
#define WM_AGENT_LEFT         (WM_USER + 7)
#define WM_TRANSCRIPT_UPDATE  (WM_USER + 8)
#define WM_AGENT_STATE_UPDATE (WM_USER + 9)

// Control IDs
#define IDC_BTN_START     2001
#define IDC_BTN_STOP      2002
#define IDC_BTN_MUTE      2003
#define IDC_LIST_MESSAGES 2004
#define IDC_LIST_LOG      2005

IMPLEMENT_DYNAMIC(CMainFrame, CFrameWnd)

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_SIZE()
    ON_BN_CLICKED(IDC_BTN_START, &CMainFrame::OnStartClicked)
    ON_BN_CLICKED(IDC_BTN_STOP, &CMainFrame::OnStopClicked)
    ON_BN_CLICKED(IDC_BTN_MUTE, &CMainFrame::OnMuteClicked)
    ON_MESSAGE(WM_TOKEN_FAILED, &CMainFrame::OnTokenFailed)
    ON_MESSAGE(WM_RTM_LOGIN_SUCCESS, &CMainFrame::OnRTMLoginSuccess)
    ON_MESSAGE(WM_RTM_LOGIN_FAILED, &CMainFrame::OnRTMLoginFailed)
    ON_MESSAGE(WM_AGENT_STARTED, &CMainFrame::OnAgentStarted)
    ON_MESSAGE(WM_AGENT_START_FAILED, &CMainFrame::OnAgentStartFailed)
    ON_MESSAGE(WM_AGENT_JOINED, &CMainFrame::OnAgentJoined)
    ON_MESSAGE(WM_AGENT_LEFT, &CMainFrame::OnAgentLeft)
    ON_MESSAGE(WM_TRANSCRIPT_UPDATE, &CMainFrame::OnTranscriptUpdate)
    ON_MESSAGE(WM_AGENT_STATE_UPDATE, &CMainFrame::OnAgentStateUpdate)
END_MESSAGE_MAP()

CMainFrame::CMainFrame() noexcept
    : m_rtcEngine(nullptr)
    , m_rtmClient(nullptr)
    , m_convoAIAPI(nullptr)
    , m_isActive(false)
    , m_isMuted(false)
    , m_rtmLoggedIn(false)
    , m_userUid(9998)
    , m_agentUid(9999)
{
}

CMainFrame::~CMainFrame()
{
    // Cleanup ConvoAI
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }
    
    // Cleanup RTM
    if (m_rtmClient) {
        if (m_rtmLoggedIn) {
            uint64_t reqId = 0;
            m_rtmClient->logout(reqId);
        }
        m_rtmClient->release();
        m_rtmClient = nullptr;
    }
    m_rtmHandler.reset();
    
    // Cleanup RTC
    if (m_rtcEngine) {
        m_rtcEngine->leaveChannel();
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
    }
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    if (!CFrameWnd::PreCreateWindow(cs))
        return FALSE;

    cs.dwExStyle &= ~WS_EX_CLIENTEDGE;
    cs.lpszClass = AfxRegisterWndClass(0);
    cs.cx = 1200;
    cs.cy = 800;
    cs.x = (GetSystemMetrics(SM_CXSCREEN) - cs.cx) / 2;
    cs.y = (GetSystemMetrics(SM_CYSCREEN) - cs.cy) / 2;

    return TRUE;
}

#ifdef _DEBUG
void CMainFrame::AssertValid() const { CFrameWnd::AssertValid(); }
void CMainFrame::Dump(CDumpContext& dc) const { CFrameWnd::Dump(dc); }
#endif

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    if (CFrameWnd::OnCreate(lpCreateStruct) == -1)
        return -1;

    m_normalFont.CreatePointFont(90, _T("Segoe UI"));
    m_smallFont.CreatePointFont(80, _T("Consolas"));
    
    SetupUI();
    SetupSDK();

    return 0;
}

// ============================================================================
// UI Setup
// ============================================================================

void CMainFrame::SetupUI()
{
    SetupLogPanel();
    SetupTopPanel();
    SetupBottomPanel();
}

void CMainFrame::SetupTopPanel()
{
    m_topPanel.Create(_T(""), WS_CHILD | WS_VISIBLE, CRect(0, 0, 10, 10), this);
    
    m_listMessages.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_MESSAGES);
    m_listMessages.SetFont(&m_normalFont);
    m_listMessages.SetExtendedStyle(LVS_EX_FULLROWSELECT);
    m_listMessages.InsertColumn(0, _T("Messages"), LVCFMT_LEFT, 500);
    
    m_labelAgentStatus.Create(_T("Agent: Not Started"), WS_CHILD | WS_VISIBLE | SS_RIGHT,
        CRect(0, 0, 10, 10), this);
    m_labelAgentStatus.SetFont(&m_normalFont);
}

void CMainFrame::SetupLogPanel()
{
    m_logPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_ETCHEDFRAME, CRect(0, 0, 10, 10), this);
    
    m_listLog.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_LOG);
    m_listLog.SetFont(&m_smallFont);
    m_listLog.SetExtendedStyle(LVS_EX_FULLROWSELECT);
    m_listLog.InsertColumn(0, _T("Log"), LVCFMT_LEFT, LOG_PANEL_WIDTH - 20);
}

void CMainFrame::SetupBottomPanel()
{
    m_bottomPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_ETCHEDHORZ, CRect(0, 0, 10, 10), this);
    
    m_btnStart.Create(_T("Start Agent"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_START);
    m_btnStart.SetFont(&m_normalFont);
    
    m_btnMute.Create(_T("Mute"), WS_CHILD | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_MUTE);
    m_btnMute.SetFont(&m_normalFont);
    
    m_btnStop.Create(_T("Stop Agent"), WS_CHILD | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_STOP);
    m_btnStop.SetFont(&m_normalFont);
}

void CMainFrame::LayoutPanels()
{
    CRect clientRect;
    GetClientRect(&clientRect);
    
    if (clientRect.Width() <= 0 || clientRect.Height() <= 0)
        return;
    
    int logLeft = clientRect.right - LOG_PANEL_WIDTH;
    int bottomTop = clientRect.bottom - BOTTOM_PANEL_HEIGHT;
    int contentWidth = logLeft - PADDING;
    
    // Log panel
    m_logPanel.MoveWindow(logLeft, 0, LOG_PANEL_WIDTH, clientRect.Height());
    m_listLog.MoveWindow(logLeft, 0, LOG_PANEL_WIDTH, clientRect.Height());
    m_listLog.SetColumnWidth(0, LOG_PANEL_WIDTH - 20);
    
    // Top panel
    m_topPanel.MoveWindow(0, 0, contentWidth, bottomTop);
    int msgWidth = contentWidth - PADDING * 2;
    int msgHeight = bottomTop - PADDING - 30;
    m_listMessages.MoveWindow(PADDING, PADDING, msgWidth, msgHeight);
    m_listMessages.SetColumnWidth(0, msgWidth - 20);
    m_labelAgentStatus.MoveWindow(PADDING, bottomTop - 25, msgWidth, 20);
    
    // Bottom panel
    m_bottomPanel.MoveWindow(0, bottomTop, contentWidth, BOTTOM_PANEL_HEIGHT);
    int btnY = bottomTop + (BOTTOM_PANEL_HEIGHT - BUTTON_HEIGHT) / 2;
    int btnWidth = contentWidth - PADDING * 2;
    int halfWidth = (btnWidth - 8) / 2;
    
    m_btnStart.MoveWindow(PADDING, btnY, btnWidth, BUTTON_HEIGHT);
    m_btnMute.MoveWindow(PADDING, btnY, halfWidth, BUTTON_HEIGHT);
    m_btnStop.MoveWindow(PADDING + halfWidth + 8, btnY, halfWidth, BUTTON_HEIGHT);
}

void CMainFrame::OnSize(UINT nType, int cx, int cy)
{
    CFrameWnd::OnSize(nType, cx, cy);
    
    if (cx > 0 && cy > 0 && ::IsWindow(m_listMessages.GetSafeHwnd())) {
        LayoutPanels();
    }
}

// ============================================================================
// UI Helpers
// ============================================================================

void CMainFrame::UpdateAgentStatus(const CString& message)
{
    CString text;
    text.Format(_T("Agent: %s"), message);
    m_labelAgentStatus.SetWindowText(text);
}

void CMainFrame::ShowIdleButtons()
{
    m_btnStart.ShowWindow(SW_SHOW);
    m_btnStart.EnableWindow(TRUE);
    m_btnMute.ShowWindow(SW_HIDE);
    m_btnStop.ShowWindow(SW_HIDE);
}

void CMainFrame::ShowActiveButtons()
{
    m_btnStart.ShowWindow(SW_HIDE);
    m_btnMute.ShowWindow(SW_SHOW);
    m_btnMute.EnableWindow(TRUE);
    m_btnStop.ShowWindow(SW_SHOW);
    m_btnStop.EnableWindow(TRUE);
}

void CMainFrame::UpdateTranscripts()
{
    m_listMessages.DeleteAllItems();
    
    for (size_t i = 0; i < m_transcripts.size(); ++i) {
        const Transcript& t = m_transcripts[i];
        CString prefix = (t.type == TranscriptType::Agent) ? _T("[Agent] ") : _T("[User] ");
        CString text = prefix + StringUtils::Utf8ToCString(t.text);
        m_listMessages.InsertItem((int)i, text);
    }
    
    if (m_transcripts.size() > 0) {
        m_listMessages.EnsureVisible((int)m_transcripts.size() - 1, FALSE);
    }
}

void CMainFrame::LogToView(const CString& message)
{
    time_t now = time(nullptr);
    struct tm timeinfo;
    localtime_s(&timeinfo, &now);
    
    CString timestamp;
    timestamp.Format(_T("[%02d:%02d:%02d] "), timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    
    CString logLine = timestamp + message;
    int index = m_listLog.GetItemCount();
    m_listLog.InsertItem(index, logLine);
    m_listLog.EnsureVisible(index, FALSE);
    
    LOG_INFO(std::string(CT2A(message)));
}

// ============================================================================
// SDK Setup (Direct management like macOS)
// ============================================================================

void CMainFrame::SetupSDK()
{
    m_listLog.DeleteAllItems();
    InitializeRTC();
    InitializeRTM();
    UpdateAgentStatus(_T("Not Started"));
}

void CMainFrame::InitializeRTC()
{
    m_rtcEngine = agora::rtc::createAgoraRtcEngine();
    if (!m_rtcEngine) {
        LogToView(_T("RTC init FAIL"));
        return;
    }
    
    agora::rtc::RtcEngineContext context;
    context.appId = KeyCenter::AGORA_APP_ID;
    context.eventHandler = this;
    context.audioScenario = agora::rtc::AUDIO_SCENARIO_DEFAULT;
    
    int ret = m_rtcEngine->initialize(context);
    if (ret != 0) {
        LogToView(_T("RTC init FAIL"));
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
        return;
    }
    
    m_rtcEngine->setChannelProfile(agora::CHANNEL_PROFILE_LIVE_BROADCASTING);
    m_rtcEngine->enableAudio();
    m_rtcEngine->disableVideo();
    m_rtcEngine->setClientRole(agora::rtc::CLIENT_ROLE_BROADCASTER);
    m_rtcEngine->enableLocalAudio(true);
    
    CString msg;
    msg.Format(_T("RTC init OK, v%S"), m_rtcEngine->getVersion(nullptr));
    LogToView(msg);
}

void CMainFrame::InitializeRTM()
{
    m_rtmHandler = std::make_unique<RtmEventHandler>(this);
    
    agora::rtm::RtmConfig config;
    config.appId = KeyCenter::AGORA_APP_ID;
    config.userId = std::to_string(m_userUid).c_str();
    config.eventHandler = m_rtmHandler.get();
    config.presenceTimeout = 300;
    config.useStringUserId = true;
    config.areaCode = agora::rtm::RTM_AREA_CODE_GLOB;
    
    int errorCode = 0;
    m_rtmClient = agora::rtm::createAgoraRtmClient(config, errorCode);
    
    if (m_rtmClient && errorCode == 0) {
        LogToView(_T("RTM init OK"));
    } else {
        LogToView(_T("RTM init FAIL"));
    }
}

void CMainFrame::InitializeConvoAI()
{
    if (m_convoAIAPI) return;
    
    m_convoAIAPI = std::make_unique<ConversationalAIAPI>();
    m_convoAIAPI->AddHandler(this);
}

// ============================================================================
// Actions
// ============================================================================

void CMainFrame::OnStartClicked()
{
    m_btnStart.EnableWindow(FALSE);
    StartSession();
}

void CMainFrame::OnStopClicked()
{
    m_btnStop.EnableWindow(FALSE);
    StopSession();
}

void CMainFrame::OnMuteClicked()
{
    m_isMuted = !m_isMuted;
    m_btnMute.SetWindowText(m_isMuted ? _T("Unmute") : _T("Mute"));
    if (m_rtcEngine) {
        m_rtcEngine->adjustRecordingSignalVolume(m_isMuted ? 0 : 100);
    }
}

// ============================================================================
// Session Management
// ============================================================================

void CMainFrame::StartSession()
{
    m_channelName = GenerateRandomChannelName();
    m_transcripts.clear();
    m_listMessages.DeleteAllItems();
    UpdateAgentStatus(_T("Generating token..."));
    
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    
    TokenGenerator::GenerateToken(m_channelName, std::to_string(m_userUid), 86400, types,
        [this](bool success, const std::string& token, const std::string& error) {
            if (!GetSafeHwnd()) return;
            
            if (!success) {
                LogToView(_T("Token FAIL"));
                PostMessage(WM_TOKEN_FAILED, 0, 0);
                return;
            }
            
            LogToView(_T("Token OK"));
            m_token = token;
            UpdateAgentStatus(_T("Joining..."));
            
            JoinRTCChannel(token);
            LoginRTM(token);
        }
    );
}

void CMainFrame::StopSession()
{
    UpdateAgentStatus(_T("Stopping..."));
    
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }
    
    if (!m_agentId.empty()) {
        AgentManager::StopAgent(m_agentId, [](bool, const std::string&) {});
    }
    
    if (m_rtmLoggedIn && m_rtmClient) {
        uint64_t reqId = 0;
        m_rtmClient->logout(reqId);
        m_rtmLoggedIn = false;
    }
    
    if (m_rtcEngine) {
        m_rtcEngine->leaveChannel();
    }
    
    // Reset state
    m_channelName.clear();
    m_token.clear();
    m_agentToken.clear();
    m_agentId.clear();
    m_isActive = false;
    m_isMuted = false;
    m_transcripts.clear();
    
    m_listMessages.DeleteAllItems();
    m_btnMute.SetWindowText(_T("Mute"));
    ShowIdleButtons();
    UpdateAgentStatus(_T("Not Started"));
}

void CMainFrame::JoinRTCChannel(const std::string& token)
{
    if (!m_rtcEngine) {
        LogToView(_T("joinChannel FAIL"));
        return;
    }
    
    agora::rtc::ChannelMediaOptions options;
    options.clientRoleType = agora::rtc::CLIENT_ROLE_BROADCASTER;
    options.publishMicrophoneTrack = true;
    options.publishCameraTrack = false;
    options.autoSubscribeAudio = true;
    options.autoSubscribeVideo = false;
    
    int ret = m_rtcEngine->joinChannel(token.c_str(), m_channelName.c_str(), m_userUid, options);
    
    CString msg;
    msg.Format(_T("joinChannel ret=%d"), ret);
    LogToView(msg);
}

void CMainFrame::LoginRTM(const std::string& token)
{
    if (!m_rtmClient) {
        LogToView(_T("RTM login FAIL"));
        PostMessage(WM_RTM_LOGIN_FAILED, 0, 0);
        return;
    }
    
    uint64_t requestId = 0;
    m_rtmClient->login(token.c_str(), requestId);
}

void CMainFrame::StartAgent()
{
    UpdateAgentStatus(_T("Starting agent..."));
    
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    
    TokenGenerator::GenerateToken(m_channelName, std::to_string(m_agentUid), 86400, types,
        [this](bool success, const std::string& token, const std::string& error) {
            if (!GetSafeHwnd()) return;
            
            if (!success) {
                LogToView(_T("Agent token FAIL"));
                PostMessage(WM_AGENT_START_FAILED, 0, 0);
                return;
            }
            
            LogToView(_T("Agent token OK"));
            m_agentToken = token;
            
            AgentManager::StartAgent(m_channelName, std::to_string(m_agentUid), token,
                [this](bool success, const std::string& agentIdOrError) {
                    if (!GetSafeHwnd()) return;
                    
                    if (!success) {
                        LogToView(_T("Agent start FAIL"));
                        PostMessage(WM_AGENT_START_FAILED, 0, 0);
                        return;
                    }
                    
                    LogToView(_T("Agent start OK"));
                    m_agentId = agentIdOrError;
                    m_isActive = true;
                    PostMessage(WM_AGENT_STARTED, 0, 0);
                }
            );
        }
    );
}

std::string CMainFrame::GenerateRandomChannelName()
{
    int randomNumber = rand() % 9000 + 1000;
    return "channel_windows_" + std::to_string(randomNumber);
}

// ============================================================================
// RTC Callbacks
// ============================================================================

void CMainFrame::onJoinChannelSuccess(const char* channel, agora::rtc::uid_t uid, int elapsed)
{
    CString msg;
    msg.Format(_T("onJoinSuccess uid=%u"), uid);
    LogToView(msg);
}

void CMainFrame::onLeaveChannel(const agora::rtc::RtcStats& stats)
{
    LogToView(_T("onLeaveChannel"));
}

void CMainFrame::onUserJoined(agora::rtc::uid_t uid, int elapsed)
{
    CString msg;
    msg.Format(_T("onUserJoined uid=%u"), uid);
    LogToView(msg);
    
    if (uid == m_agentUid && m_isActive) {
        PostMessage(WM_AGENT_JOINED, 0, 0);
    }
}

void CMainFrame::onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE reason)
{
    CString msg;
    msg.Format(_T("onUserOffline uid=%u"), uid);
    LogToView(msg);
    
    if (uid == m_agentUid && m_isActive) {
        PostMessage(WM_AGENT_LEFT, 0, 0);
    }
}

void CMainFrame::onTokenPrivilegeWillExpire(const char* token)
{
    LogToView(_T("Token expiring"));
}

void CMainFrame::onError(int err, const char* msg)
{
    CString logMsg;
    logMsg.Format(_T("onError code=%d"), err);
    LogToView(logMsg);
}

// ============================================================================
// RTM Callbacks
// ============================================================================

void CMainFrame::OnRtmLoginResult(int errorCode)
{
    if (errorCode == 0) {
        m_rtmLoggedIn = true;
        LogToView(_T("RTM login OK"));
        PostMessage(WM_RTM_LOGIN_SUCCESS, 0, 0);
    } else {
        LogToView(_T("RTM login FAIL"));
        PostMessage(WM_RTM_LOGIN_FAILED, 0, 0);
    }
}

void CMainFrame::OnRtmMessage(const char* message, const char* publisher)
{
    // Forward to ConversationalAIAPI if available
    if (m_convoAIAPI) {
        m_convoAIAPI->HandleMessage(message, publisher);
    }
}

// RTM Event Handler Implementation
void CMainFrame::RtmEventHandler::onLoginResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode)
{
    m_frame->OnRtmLoginResult(errorCode);
}

void CMainFrame::RtmEventHandler::onMessageEvent(const MessageEvent& event)
{
    if (event.message && event.messageLength > 0) {
        std::string msg(event.message, event.messageLength);
        std::string publisher = event.publisher ? event.publisher : "";
        m_frame->OnRtmMessage(msg.c_str(), publisher.c_str());
    }
}

void CMainFrame::RtmEventHandler::onPresenceEvent(const PresenceEvent& event)
{
    // Handle presence events for agent state
    if (event.stateItemCount > 0 && event.stateItems) {
        std::string agentState;
        std::string turnIdStr;
        
        for (size_t i = 0; i < event.stateItemCount; ++i) {
            std::string key = event.stateItems[i].key ? event.stateItems[i].key : "";
            std::string value = event.stateItems[i].value ? event.stateItems[i].value : "";
            
            if (key == "state") agentState = value;
            else if (key == "turn_id") turnIdStr = value;
        }
        
        if (!agentState.empty()) {
            std::string stateMessage = "{"
                "\"object\": \"message.state\","
                "\"state\": \"" + agentState + "\","
                "\"turn_id\": " + (turnIdStr.empty() ? "0" : turnIdStr) + ","
                "\"timestamp\": " + std::to_string(event.timestamp) + ","
                "\"reason\": \"\""
                "}";
            
            std::string agentUserId = event.publisher ? event.publisher : "";
            m_frame->OnRtmMessage(stateMessage.c_str(), agentUserId.c_str());
        }
    }
}

void CMainFrame::RtmEventHandler::onLinkStateEvent(const LinkStateEvent& event)
{
    // Log connection state changes if needed
}

void CMainFrame::RtmEventHandler::onSubscribeResult(const uint64_t requestId, const char* channelName, agora::rtm::RTM_ERROR_CODE errorCode)
{
    // Handle subscribe result if needed
}

// ============================================================================
// ConvoAI Callbacks
// ============================================================================

void CMainFrame::OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript)
{
    bool found = false;
    for (size_t i = 0; i < m_transcripts.size(); ++i) {
        if (m_transcripts[i].turnId == transcript.turnId &&
            m_transcripts[i].type == transcript.type &&
            m_transcripts[i].userId == transcript.userId) {
            m_transcripts[i] = transcript;
            found = true;
            break;
        }
    }
    
    if (!found) {
        m_transcripts.push_back(transcript);
    }
    
    PostMessage(WM_TRANSCRIPT_UPDATE, 0, 0);
}

void CMainFrame::OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event)
{
    PostMessage(WM_AGENT_STATE_UPDATE, (WPARAM)event.state, 0);
}

// ============================================================================
// Async Message Handlers
// ============================================================================

LRESULT CMainFrame::OnTokenFailed(WPARAM wParam, LPARAM lParam)
{
    UpdateAgentStatus(_T("Token failed"));
    ShowIdleButtons();
    return 0;
}

LRESULT CMainFrame::OnRTMLoginSuccess(WPARAM wParam, LPARAM lParam)
{
    // Initialize ConvoAI
    InitializeConvoAI();
    
    // Subscribe to channel
    if (m_rtmClient) {
        agora::rtm::SubscribeOptions options;
        options.withMessage = true;
        options.withPresence = true;
        options.withMetadata = false;
        options.withLock = false;
        
        uint64_t reqId = 0;
        m_rtmClient->subscribe(m_channelName.c_str(), options, reqId);
    }
    
    StartAgent();
    return 0;
}

LRESULT CMainFrame::OnRTMLoginFailed(WPARAM wParam, LPARAM lParam)
{
    UpdateAgentStatus(_T("RTM login failed"));
    ShowIdleButtons();
    return 0;
}

LRESULT CMainFrame::OnAgentStarted(WPARAM wParam, LPARAM lParam)
{
    ShowActiveButtons();
    UpdateAgentStatus(_T("Launching..."));
    return 0;
}

LRESULT CMainFrame::OnAgentStartFailed(WPARAM wParam, LPARAM lParam)
{
    UpdateAgentStatus(_T("Start failed"));
    StopSession();
    return 0;
}

LRESULT CMainFrame::OnAgentJoined(WPARAM wParam, LPARAM lParam)
{
    if (m_isActive) {
        UpdateAgentStatus(_T("Connected"));
    }
    return 0;
}

LRESULT CMainFrame::OnAgentLeft(WPARAM wParam, LPARAM lParam)
{
    if (m_isActive) {
        UpdateAgentStatus(_T("Disconnected"));
    }
    return 0;
}

LRESULT CMainFrame::OnTranscriptUpdate(WPARAM wParam, LPARAM lParam)
{
    UpdateTranscripts();
    return 0;
}

LRESULT CMainFrame::OnAgentStateUpdate(WPARAM wParam, LPARAM lParam)
{
    AgentState state = (AgentState)wParam;
    
    CString stateText;
    switch (state) {
        case AgentState::Idle: stateText = _T("Idle"); break;
        case AgentState::Silent: stateText = _T("Silent"); break;
        case AgentState::Listening: stateText = _T("Listening"); break;
        case AgentState::Thinking: stateText = _T("Thinking"); break;
        case AgentState::Speaking: stateText = _T("Speaking"); break;
        default: stateText = _T("Unknown"); break;
    }
    
    UpdateAgentStatus(stateText);
    return 0;
}
