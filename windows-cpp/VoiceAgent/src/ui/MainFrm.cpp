// MainFrm.cpp

#include "../General/pch.h"
#include "../General/framework.h"
#include "../General/VoiceAgent.h"
#include "MainFrm.h"
#include "../../resources/Resource.h"
#include "../KeyCenter.h"
#include "../tools/Logger.h"
#include "../tools/StringUtils.h"
#include "../api/TokenGenerator.h"
#include "../api/AgentManager.h"
#include <sstream>
#include <iomanip>
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
#define IDC_BTN_START    2001
#define IDC_BTN_STOP     2002
#define IDC_BTN_MUTE     2003
#define IDC_LIST_MESSAGES 2004
#define IDC_LIST_LOG     2005

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
    : m_rtcManager(RtcManager::GetInstance())
    , m_rtmManager(RtmManager::GetInstance())
    , m_convoAIAPI(nullptr)
    , m_isActive(false)
    , m_isMuted(false)
    , m_userUid(9998)
    , m_agentUid(9999)
{
}

CMainFrame::~CMainFrame()
{
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }
    m_rtmManager.SetEventHandler(nullptr);
    m_rtmManager.Destroy();
    m_rtcManager.Destroy();
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
    // Create all controls first, layout will be done in OnSize
    SetupLogPanel();
    SetupTopPanel();
    SetupBottomPanel();
}

void CMainFrame::SetupTopPanel()
{
    // Top panel background
    m_topPanel.Create(_T(""), WS_CHILD | WS_VISIBLE, CRect(0, 0, 10, 10), this);
    
    // Message list
    m_listMessages.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_MESSAGES);
    m_listMessages.SetFont(&m_normalFont);
    m_listMessages.SetExtendedStyle(LVS_EX_FULLROWSELECT);
    m_listMessages.InsertColumn(0, _T("Messages"), LVCFMT_LEFT, 500);
    
    // Agent status label
    m_labelAgentStatus.Create(_T("Agent: Not Started"), WS_CHILD | WS_VISIBLE | SS_RIGHT,
        CRect(0, 0, 10, 10), this);
    m_labelAgentStatus.SetFont(&m_normalFont);
}

void CMainFrame::SetupLogPanel()
{
    // Log panel border (visual only)
    m_logPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_ETCHEDFRAME, CRect(0, 0, 10, 10), this);
    
    // Log list
    m_listLog.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(0, 0, 10, 10), this, IDC_LIST_LOG);
    m_listLog.SetFont(&m_smallFont);
    m_listLog.SetExtendedStyle(LVS_EX_FULLROWSELECT);
    m_listLog.InsertColumn(0, _T("Log"), LVCFMT_LEFT, LOG_PANEL_WIDTH - 20);
}

void CMainFrame::SetupBottomPanel()
{
    // Bottom panel background with border
    m_bottomPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_ETCHEDHORZ, CRect(0, 0, 10, 10), this);
    
    // Start button (shown when idle)
    m_btnStart.Create(_T("Start Agent"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_START);
    m_btnStart.SetFont(&m_normalFont);
    
    // Mute button (shown when active)
    m_btnMute.Create(_T("Mute"), WS_CHILD | BS_PUSHBUTTON,
        CRect(0, 0, 10, 10), this, IDC_BTN_MUTE);
    m_btnMute.SetFont(&m_normalFont);
    
    // Stop button (shown when active)
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
    
    // Log panel (right side, full height)
    m_logPanel.MoveWindow(logLeft, 0, LOG_PANEL_WIDTH, clientRect.Height());
    m_listLog.MoveWindow(logLeft, 0, LOG_PANEL_WIDTH, clientRect.Height());
    m_listLog.SetColumnWidth(0, LOG_PANEL_WIDTH - 20);
    
    // Top panel background
    m_topPanel.MoveWindow(0, 0, contentWidth, bottomTop);
    
    // Message list (absolute coordinates)
    int msgWidth = contentWidth - PADDING * 2;
    int msgHeight = bottomTop - PADDING - 30;
    m_listMessages.MoveWindow(PADDING, PADDING, msgWidth, msgHeight);
    m_listMessages.SetColumnWidth(0, msgWidth - 20);
    
    // Agent status label (absolute coordinates, bottom of top area)
    m_labelAgentStatus.MoveWindow(PADDING, bottomTop - 25, msgWidth, 20);
    
    // Bottom panel background
    m_bottomPanel.MoveWindow(0, bottomTop, contentWidth, BOTTOM_PANEL_HEIGHT);
    
    // Button layout (absolute coordinates)
    int btnY = bottomTop + (BOTTOM_PANEL_HEIGHT - BUTTON_HEIGHT) / 2;
    int btnWidth = contentWidth - PADDING * 2;
    int halfWidth = (btnWidth - 8) / 2;
    
    // Start button (full width)
    m_btnStart.MoveWindow(PADDING, btnY, btnWidth, BUTTON_HEIGHT);
    
    // Mute + Stop buttons (half width each)
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
    // Get current time
    time_t now = time(nullptr);
    struct tm timeinfo;
    localtime_s(&timeinfo, &now);
    
    CString timestamp;
    timestamp.Format(_T("[%02d:%02d:%02d] "), timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    
    CString logLine = timestamp + message;
    
    // Add to log list
    int index = m_listLog.GetItemCount();
    m_listLog.InsertItem(index, logLine);
    m_listLog.EnsureVisible(index, FALSE);
    
    // Also print to debug output
    LOG_INFO(std::string(CT2A(message)));
}

// ============================================================================
// SDK Setup
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
    agora::rtc::IRtcEngine* engine = m_rtcManager.CreateRtcEngine(this);
    if (engine) {
        LogToView(_T("RTC init OK"));
    } else {
        LogToView(_T("RTC init FAIL"));
    }
}

void CMainFrame::InitializeRTM()
{
    RtmManagerConfig config;
    config.appId = KeyCenter::AGORA_APP_ID;
    config.userId = std::to_string(m_userUid);
    
    if (m_rtmManager.Initialize(config)) {
        m_rtmManager.SetEventHandler(this);
        LogToView(_T("RTM init OK"));
    } else {
        LogToView(_T("RTM init FAIL"));
    }
}

void CMainFrame::InitializeConvoAI()
{
    if (m_convoAIAPI) return;
    
    m_convoAIAPI = std::make_unique<ConversationalAIAPI>(&m_rtmManager);
    m_convoAIAPI->AddHandler(this);
    m_convoAIAPI->SubscribeMessage(m_channelName, [](int, const std::string&) {});
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
    m_rtcManager.MuteLocalAudio(m_isMuted);
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
    
    // Generate user token
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
    
    m_rtmManager.Logout();
    m_rtcManager.LeaveChannel();
    
    // Reset state
    m_channelName.clear();
    m_token.clear();
    m_agentToken.clear();
    m_agentId.clear();
    m_isActive = false;
    m_isMuted = false;
    m_transcripts.clear();
    
    // Update UI
    m_listMessages.DeleteAllItems();
    m_btnMute.SetWindowText(_T("Mute"));
    ShowIdleButtons();
    UpdateAgentStatus(_T("Not Started"));
}

void CMainFrame::JoinRTCChannel(const std::string& token)
{
    if (!m_rtcManager.JoinChannel(token, m_channelName, m_userUid)) {
        LogToView(_T("joinChannel FAIL"));
        UpdateAgentStatus(_T("Join failed"));
        ShowIdleButtons();
        return;
    }
    LogToView(_T("joinChannel OK"));
}

void CMainFrame::LoginRTM(const std::string& token)
{
    m_rtmManager.Login(token, [this](int errorCode, const std::string& errorMsg) {
        if (!GetSafeHwnd()) return;
        
        if (errorCode != 0) {
            LogToView(_T("RTM login FAIL"));
            PostMessage(WM_RTM_LOGIN_FAILED, 0, 0);
            return;
        }
        
        LogToView(_T("RTM login OK"));
        PostMessage(WM_RTM_LOGIN_SUCCESS, 0, 0);
    });
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

void CMainFrame::onLoginSuccess(const char* userId) {}
void CMainFrame::onLoginFailed(int errorCode, const char* errorMessage) {}
void CMainFrame::onLogout() {}

void CMainFrame::onMessageReceived(const char* message, const char* fromUserId)
{
    if (m_convoAIAPI) {
        m_convoAIAPI->HandleMessage(message, fromUserId);
    }
}

void CMainFrame::onConnectionStateChanged(agora::rtm::RTM_LINK_STATE state, agora::rtm::RTM_LINK_STATE_CHANGE_REASON reason) {}

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
    InitializeConvoAI();
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
