// MainFrm.cpp: CMainFrame class implementation

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

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

// CMainFrame

IMPLEMENT_DYNAMIC(CMainFrame, CFrameWnd)

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_SIZE()
    ON_WM_PAINT()
    ON_BN_CLICKED(IDC_BTN_START_STOP, &CMainFrame::OnStartStopClicked)
    ON_BN_CLICKED(IDC_BTN_MUTE, &CMainFrame::OnBnClickedMute)
    ON_BN_CLICKED(IDC_BTN_CLEAR, &CMainFrame::OnBnClickedClear)
    ON_MESSAGE(WM_USER + 1, &CMainFrame::OnTokenGenerationFailed)
    ON_MESSAGE(WM_USER + 2, &CMainFrame::OnAgentStopped)
    ON_MESSAGE(WM_USER + 3, &CMainFrame::OnRTMLoginSuccess)
    ON_MESSAGE(WM_USER + 4, &CMainFrame::OnAgentStartFailed)
    ON_MESSAGE(WM_USER + 6, &CMainFrame::OnAgentStarted)
    ON_MESSAGE(WM_USER + 10, &CMainFrame::OnRTCJoinSuccess)
    ON_MESSAGE(WM_USER + 11, &CMainFrame::OnRTCLeave)
    ON_MESSAGE(WM_USER + 12, &CMainFrame::OnAgentJoined)
    ON_MESSAGE(WM_USER + 13, &CMainFrame::OnAgentLeft)
    ON_MESSAGE(WM_USER + 20, &CMainFrame::OnTranscriptUpdate)
    ON_MESSAGE(WM_USER + 21, &CMainFrame::OnAgentStateUpdate)
END_MESSAGE_MAP()

// CMainFrame construction/destruction

CMainFrame::CMainFrame() noexcept
    : m_rtcManager(RtcManager::GetInstance())
    , m_rtmManager(RtmManager::GetInstance())
    , m_convoAIAPI(nullptr)
    , m_isActive(false)
    , m_isMuted(false)
    , m_userUid(9998)  // User UID
    , m_agentUid(9999)  // Agent UID
{
    LOG_INFO("[MainFrm] Constructor called");
}

CMainFrame::~CMainFrame()
{
    LOG_INFO("[MainFrm] Destructor called");
    
    // Cleanup ConvoAIAPI
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();
    }
    
    // Cleanup RTM (has internal forwarding)
    m_rtmManager.SetEventHandler(nullptr);
    m_rtmManager.Destroy();
    
    // Cleanup RTC (no internal forwarding, 'this' was passed directly to SDK)
    m_rtcManager.Destroy();
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    if (!CFrameWnd::PreCreateWindow(cs))
        return FALSE;

    cs.dwExStyle &= ~WS_EX_CLIENTEDGE;
    cs.lpszClass = AfxRegisterWndClass(0);
    
    // Set initial window size (1200x800)
    cs.cx = 1200;
    cs.cy = 800;
    cs.x = (GetSystemMetrics(SM_CXSCREEN) - cs.cx) / 2;
    cs.y = (GetSystemMetrics(SM_CYSCREEN) - cs.cy) / 2;

    return TRUE;
}

// CMainFrame diagnostics

#ifdef _DEBUG
void CMainFrame::AssertValid() const
{
    CFrameWnd::AssertValid();
}

void CMainFrame::Dump(CDumpContext& dc) const
{
    CFrameWnd::Dump(dc);
}
#endif //_DEBUG

// CMainFrame message handlers

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    if (CFrameWnd::OnCreate(lpCreateStruct) == -1)
        return -1;

    LOG_INFO("[MainFrm] OnCreate called");

    // Create fonts
    m_normalFont.CreatePointFont(90, _T("Segoe UI"));
    m_boldFont.CreatePointFont(100, _T("Segoe UI"));
    
    // Setup UI
    SetupUI();
    
    // Setup Managers (RTC, RTM)
    SetupManagers();
    
    // Initial state
    UpdateUIState(true);

    return 0;
}

void CMainFrame::SetupUI()
{
    LOG_INFO("[MainFrm] Setting up UI...");
    
    CRect clientRect;
    GetClientRect(&clientRect);
    
    // Calculate panel positions
    CRect leftRect = clientRect;
    leftRect.right = leftRect.left + LEFT_PANEL_WIDTH;
    
    CRect rightRect = clientRect;
    rightRect.left = leftRect.right + PANEL_SPACING;
    
    // Setup panels
    SetupLeftPanel(leftRect);
    SetupRightPanel(rightRect);
    
    LOG_INFO("[MainFrm] UI setup completed");
}

void CMainFrame::SetupLeftPanel(const CRect& rect)
{
    int yPos = PADDING;
    int controlWidth = rect.Width() - PADDING * 2;
    
    // Left Panel background (visual separator) - use simple style
    m_leftPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_LEFT, 
        rect, this, (UINT)IDC_STATIC);
    
    // Channel Label - create with unique ID to avoid conflicts
    CStatic* pChannelLabel = new CStatic();
    if (pChannelLabel->Create(_T("Channel Name:"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + controlWidth, yPos + 16),
        this, (UINT)IDC_STATIC))
    {
        pChannelLabel->SetFont(&m_normalFont);
    }
    yPos += 20;
    
    // Channel Input
    m_editChannel.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOHSCROLL,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + controlWidth, yPos + EDIT_HEIGHT),
        this, IDC_EDIT_CHANNEL);
    m_editChannel.SetFont(&m_normalFont);
    m_editChannel.SetWindowText(_T(""));
    yPos += EDIT_HEIGHT + 20;
    
    // Start/Stop Agent Button (combined)
    m_btnStartStop.Create(_T("Start Agent"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + controlWidth, yPos + BUTTON_HEIGHT),
        this, IDC_BTN_START_STOP);
    m_btnStartStop.SetFont(&m_normalFont);
    yPos += BUTTON_HEIGHT + 12;
    
    // Mute Button
    m_btnMute.Create(_T("Mute"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + controlWidth, yPos + BUTTON_HEIGHT),
        this, IDC_BTN_MUTE);
    m_btnMute.SetFont(&m_normalFont);
    yPos += BUTTON_HEIGHT + 20;
    
    // Separator line
    yPos += 10;
    
    // Status section title
    CStatic* pStatusLabel = new CStatic();
    if (pStatusLabel->Create(_T("Status"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + controlWidth, yPos + 20),
        this, (UINT)IDC_STATIC))
    {
        pStatusLabel->SetFont(&m_normalFont);
    }
    yPos += 24;
    
    // Line 1: Microphone (title left, detail right)
    m_labelMicTitle.Create(_T("Microphone"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + 80, yPos + 20),
        this, IDC_STATIC_MIC_TITLE);
    m_labelMicTitle.SetFont(&m_normalFont);
    
    m_labelMicDetail.Create(_T("Active"), WS_CHILD | WS_VISIBLE | SS_RIGHT,
        CRect(rect.left + PADDING + 85, yPos, rect.left + PADDING + controlWidth, yPos + 20),
        this, IDC_STATIC_MIC_DETAIL);
    m_labelMicDetail.SetFont(&m_normalFont);
    yPos += 24;
    
    // Line 2: Channel (title left, detail right)
    m_labelChannelTitle.Create(_T("Channel"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + 80, yPos + 20),
        this, IDC_STATIC_CHANNEL_TITLE);
    m_labelChannelTitle.SetFont(&m_normalFont);
    
    m_labelChannelDetail.Create(_T("Disconnected"), WS_CHILD | WS_VISIBLE | SS_RIGHT,
        CRect(rect.left + PADDING + 85, yPos, rect.left + PADDING + controlWidth, yPos + 20),
        this, IDC_STATIC_CHANNEL_DETAIL);
    m_labelChannelDetail.SetFont(&m_normalFont);
    yPos += 24;
    
    // Line 3: Agent (title left, detail right)
    m_labelAgentTitle.Create(_T("Agent"), WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, yPos, rect.left + PADDING + 80, yPos + 20),
        this, IDC_STATIC_AGENT_TITLE);
    m_labelAgentTitle.SetFont(&m_normalFont);
    
    m_labelAgentDetail.Create(_T("Not Started"), WS_CHILD | WS_VISIBLE | SS_RIGHT,
        CRect(rect.left + PADDING + 85, yPos, rect.left + PADDING + controlWidth, yPos + 20),
        this, IDC_STATIC_AGENT_DETAIL);
    m_labelAgentDetail.SetFont(&m_normalFont);
}

void CMainFrame::SetupRightPanel(const CRect& rect)
{
    // Right Panel background - use simple style
    m_rightPanel.Create(_T(""), WS_CHILD | WS_VISIBLE | SS_LEFT,
        rect, this, (UINT)IDC_STATIC);
    
    // Transcript Title Label (top left)
    m_labelTranscriptTitle.Create(_T("Conversation Transcript"), 
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, PADDING, rect.right - 100, PADDING + 25),
        this, IDC_STATIC);
    m_labelTranscriptTitle.SetFont(&m_boldFont);
    
    // Clear Button (top right)
    m_btnClear.Create(_T("Clear"), WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        CRect(rect.right - 90, PADDING, rect.right - PADDING, PADDING + 28),
        this, IDC_BTN_CLEAR);
    m_btnClear.SetFont(&m_normalFont);
    
    // Message List (below title)
    m_listMessages.Create(WS_CHILD | WS_VISIBLE | WS_BORDER | LVS_REPORT | LVS_NOCOLUMNHEADER,
        CRect(rect.left + PADDING, PADDING + 35, 
              rect.right - PADDING, rect.bottom - 60),
        this, IDC_LIST_MESSAGES);
    m_listMessages.SetFont(&m_normalFont);
    m_listMessages.SetExtendedStyle(LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES);
    
    // Add column for messages
    m_listMessages.InsertColumn(0, _T("Messages"), LVCFMT_LEFT, rect.Width() - PADDING * 2 - 20);
    
    // Transcript Count Label (bottom)
    m_labelTranscriptCount.Create(_T("Total: 0 messages"), 
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        CRect(rect.left + PADDING, rect.bottom - 40, rect.right - PADDING, rect.bottom - 20),
        this, IDC_STATIC_TRANSCRIPT_COUNT);
    m_labelTranscriptCount.SetFont(&m_normalFont);
}

void CMainFrame::OnSize(UINT nType, int cx, int cy)
{
    CFrameWnd::OnSize(nType, cx, cy);
    
    if (!::IsWindow(m_leftPanel.GetSafeHwnd()))
        return;
    
    // Recalculate panel positions
    CRect clientRect;
    GetClientRect(&clientRect);
    
    // Left panel - fixed width
    CRect leftRect(0, 0, LEFT_PANEL_WIDTH, clientRect.Height());
    m_leftPanel.MoveWindow(&leftRect);
    
    // Right panel - remaining space
    CRect rightRect(LEFT_PANEL_WIDTH + PANEL_SPACING, 0, 
                    clientRect.Width(), clientRect.Height());
    m_rightPanel.MoveWindow(&rightRect);
    
    // Reposition controls in right panel
    if (::IsWindow(m_labelTranscriptTitle.GetSafeHwnd()))
    {
        m_labelTranscriptTitle.MoveWindow(
            rightRect.left + PADDING, PADDING,
            rightRect.Width() - 110, 25);
    }
    
    if (::IsWindow(m_btnClear.GetSafeHwnd()))
    {
        m_btnClear.MoveWindow(
            rightRect.right - 90, PADDING,
            80, 28);
    }
    
    if (::IsWindow(m_listMessages.GetSafeHwnd()))
    {
        m_listMessages.MoveWindow(
            rightRect.left + PADDING, PADDING + 35,
            rightRect.Width() - PADDING * 2, 
            rightRect.Height() - 95);
        
        // Update column width
        m_listMessages.SetColumnWidth(0, rightRect.Width() - PADDING * 2 - 20);
    }
    
    if (::IsWindow(m_labelTranscriptCount.GetSafeHwnd()))
    {
        m_labelTranscriptCount.MoveWindow(
            rightRect.left + PADDING, rightRect.bottom - 40,
            rightRect.Width() - PADDING * 2, 20);
    }
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);
    
    // Draw separator line between panels
    CRect clientRect;
    GetClientRect(&clientRect);
    
    CPen pen(PS_SOLID, 1, RGB(200, 200, 200));
    CPen* pOldPen = dc.SelectObject(&pen);
    
    dc.MoveTo(LEFT_PANEL_WIDTH, 0);
    dc.LineTo(LEFT_PANEL_WIDTH, clientRect.Height());
    
    dc.SelectObject(pOldPen);
}

// ============================================================================
// Status Update Helpers
// ============================================================================

void CMainFrame::UpdateMicStatus(bool muted)
{
    if (muted)
    {
        m_labelMicDetail.SetWindowText(_T("Muted"));
    }
    else
    {
        m_labelMicDetail.SetWindowText(_T("Active"));
    }
    m_labelMicDetail.Invalidate();
}

void CMainFrame::UpdateChannelStatus(bool connected, const CString& message)
{
    if (connected)
    {
        m_labelChannelDetail.SetWindowText(message.IsEmpty() ? _T("Connected") : message);
    }
    else
    {
        m_labelChannelDetail.SetWindowText(message.IsEmpty() ? _T("Disconnected") : message);
    }
    m_labelChannelDetail.Invalidate();
}

void CMainFrame::UpdateAgentStatus(const CString& message)
{
    m_labelAgentDetail.SetWindowText(message);
    m_labelAgentDetail.Invalidate();
}

void CMainFrame::UpdateUIState(bool idle)
{
    m_editChannel.EnableWindow(idle);
    m_btnMute.EnableWindow(!idle);
}

void CMainFrame::UpdateTranscripts()
{
    // Clear existing items
    m_listMessages.DeleteAllItems();
    
    // Add all transcripts to list
    for (size_t i = 0; i < m_transcripts.size(); ++i) {
        const Transcript& transcript = m_transcripts[i];
        
        // Format: [Type] Text
        CString typeStr = (transcript.type == TranscriptType::Agent) ? _T("[Agent]") : _T("[User]");
        // Convert UTF-8 to Unicode CString for UI display
        CString textStr = StringUtils::Utf8ToCString(transcript.text);
        CString displayText;
        displayText.Format(_T("%s %s"), typeStr, textStr);
        
        int index = m_listMessages.InsertItem((int)i, displayText);
        
        // Set color based on type (subitem 1 stores type for coloring)
        m_listMessages.SetItemText(index, 1, typeStr);
    }
    
    // Update transcript count
    CString countText;
    countText.Format(_T("Total: %d messages"), (int)m_transcripts.size());
    m_labelTranscriptCount.SetWindowText(countText);
    
    // Auto-scroll to bottom
    if (m_transcripts.size() > 0) {
        m_listMessages.EnsureVisible((int)m_transcripts.size() - 1, FALSE);
    }
}

// Button click handlers

void CMainFrame::OnStartStopClicked()
{
    LOG_INFO("[MainFrm] Start/Stop button clicked");
    
    // Disable button to prevent repeated clicks
    m_btnStartStop.EnableWindow(FALSE);
    
    if (m_isActive)
    {
        StopAgentAndLeaveChannel();
    }
    else
    {
        JoinChannelAndStartAgent();
    }
}

void CMainFrame::OnBnClickedMute()
{
    LOG_INFO("[MainFrm] Mute button clicked");
    
    m_isMuted = !m_isMuted;
    
    if (m_isMuted)
    {
        m_btnMute.SetWindowText(_T("Unmute"));
    }
    else
    {
        m_btnMute.SetWindowText(_T("Mute"));
    }
    
    UpdateMicStatus(m_isMuted);
    RtcManager::GetInstance().MuteLocalAudio(m_isMuted);
}

void CMainFrame::OnBnClickedClear()
{
    LOG_INFO("[MainFrm] Clear button clicked");
    
    m_transcripts.clear();
    m_listMessages.DeleteAllItems();
    UpdateTranscripts();
}

// Business logic methods

/// Join channel and start agent (combined operation, similar to macOS)
void CMainFrame::JoinChannelAndStartAgent()
{
    LOG_INFO("[MainFrm] JoinChannelAndStartAgent called");
    
    CString channelText;
    m_editChannel.GetWindowText(channelText);
    
    if (channelText.IsEmpty())
    {
        // Generate random channel name
        m_channelName = GenerateRandomChannelName();
        m_editChannel.SetWindowText(CString(m_channelName.c_str()));
    }
    else
    {
        m_channelName = std::string(CT2A(channelText));
    }
    
    // Clear old transcripts when starting
    m_transcripts.clear();
    m_listMessages.DeleteAllItems();
    UpdateTranscripts();
    
    UpdateChannelStatus(false, _T("Generating token..."));
    UpdateAgentStatus(_T("Initializing..."));
    
    // Step 1: Generate token for user
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    
    TokenGenerator::GenerateToken(
        m_channelName,
        std::to_string(m_userUid),
        86400,
        types,
        [this](bool success, const std::string& token, const std::string& error) {
            // Safety check: ensure window is still valid
            if (!GetSafeHwnd()) {
                LOG_WARN("[MainFrm] Window destroyed, ignoring token callback");
                return;
            }
            
            if (!success) {
                LOG_ERROR("[MainFrm] Token generation failed: " + error);
                // Re-enable button on failure
                m_btnStartStop.EnableWindow(TRUE);
                this->PostMessage(WM_USER + 1, 0, 0);
                return;
            }
            
            m_token = token;
            LOG_INFO("[MainFrm] Token generated successfully");
            
            UpdateChannelStatus(false, _T("Joining..."));
            
            // Join RTC channel
            if (!m_rtcManager.JoinChannel(token, m_channelName, m_userUid)) {
                LOG_ERROR("[MainFrm] Failed to join RTC channel");
                UpdateChannelStatus(false, _T("Join failed"));
                UpdateAgentStatus(_T("Failed"));
                m_btnStartStop.EnableWindow(TRUE);
                return;
            }
            
            // Login RTM
            m_rtmManager.Login(token, [this](int errorCode, const std::string& errorMsg) {
                // Safety check: ensure window is still valid
                if (!GetSafeHwnd()) {
                    LOG_WARN("[MainFrm] Window destroyed, ignoring RTM login callback");
                    return;
                }
                
                if (errorCode != 0) {
                    LOG_ERROR("[MainFrm] RTM login failed: " + errorMsg);
                    m_btnStartStop.EnableWindow(TRUE);
                    UpdateChannelStatus(false, _T("RTM login failed"));
                    UpdateAgentStatus(_T("Failed"));
                    return;
                }
                
                LOG_INFO("[MainFrm] RTM login success");
                
                // Update UI on main thread
                this->PostMessage(WM_USER + 3, 0, 0);
                
                // Step 2: Initialize ConvoAIAPI after RTM is ready
                InitializeConvoAIAPI();
                
                // Step 3: Start agent
                StartAgent();
            });
        }
    );
}

/// Stop agent and leave channel (combined operation, similar to macOS)
void CMainFrame::StopAgentAndLeaveChannel()
{
    LOG_INFO("[MainFrm] StopAgentAndLeaveChannel called");
    
    UpdateAgentStatus(_T("Stopping..."));
    
    // Step 1: Stop agent if running
    if (!m_agentId.empty()) {
        AgentManager::StopAgent(m_agentId, [this](bool success, const std::string& messageOrError) {
            if (!GetSafeHwnd()) {
                LOG_WARN("[MainFrm] Window destroyed, ignoring agent stop callback");
                return;
            }
            
            if (!success) {
                LOG_ERROR("[MainFrm] Agent stop failed: " + messageOrError);
            } else {
                LOG_INFO("[MainFrm] Agent stopped successfully");
            }
        });
    }
    
    // Step 2: Cleanup ConvoAIAPI (RAII - unique_ptr automatically manages memory)
    if (m_convoAIAPI) {
        m_convoAIAPI->RemoveHandler(this);
        m_convoAIAPI.reset();  // Calls destructor and sets to nullptr
    }
    
    // Step 3: Logout RTM
    m_rtmManager.Logout();
    
    // Step 4: Leave RTC channel
    m_rtcManager.LeaveChannel();
    
    // Step 5: Reset all state
    m_isActive = false;
    m_channelName.clear();
    m_token.clear();
    m_agentToken.clear();
    m_agentId.clear();
    
    // Clear transcripts
    m_transcripts.clear();
    m_listMessages.DeleteAllItems();
    
    // Update UI
    m_btnStartStop.SetWindowText(_T("Start Agent"));
    m_btnStartStop.EnableWindow(TRUE);  // Re-enable button
    m_btnMute.SetWindowText(_T("Mute"));
    
    // Reset all status labels
    UpdateMicStatus(false);
    UpdateChannelStatus(false, _T("Disconnected"));
    UpdateAgentStatus(_T("Not Started"));
    
    UpdateUIState(true);
    UpdateTranscripts();
    
    LOG_INFO("[MainFrm] Stop agent and leave channel completed");
}

/// Start agent after channel is joined (Step 3 of JoinChannelAndStartAgent)
void CMainFrame::StartAgent()
{
    LOG_INFO("[MainFrm] StartAgent called");
    
    UpdateAgentStatus(_T("Generating agent token..."));
    
    // Generate token for agent
    std::vector<AgoraTokenType> types = { AgoraTokenType::RTC, AgoraTokenType::RTM };
    
    TokenGenerator::GenerateToken(
        m_channelName,
        std::to_string(m_agentUid),
        86400,
        types,
        [this](bool success, const std::string& token, const std::string& error) {
            // Safety check: ensure window is still valid
            if (!GetSafeHwnd()) {
                LOG_WARN("[MainFrm] Window destroyed, ignoring agent token callback");
                return;
            }
            
            if (!success) {
                LOG_ERROR("[MainFrm] Agent token generation failed: " + error);
                m_btnStartStop.EnableWindow(TRUE);
                this->PostMessage(WM_USER + 4, 0, 0);
                return;
            }
            
            m_agentToken = token;
            LOG_INFO("[MainFrm] Agent token generated successfully");
            
            UpdateAgentStatus(_T("Starting agent..."));
            
            // Start agent using AgentManager
            AgentManager::StartAgent(
                m_channelName,
                std::to_string(m_agentUid),
                token,
                [this](bool success, const std::string& agentIdOrError) {
                    // Safety check: ensure window is still valid
                    if (!GetSafeHwnd()) {
                        LOG_WARN("[MainFrm] Window destroyed, ignoring agent start callback");
                        return;
                    }
                    
                    if (!success) {
                        LOG_ERROR("[MainFrm] Agent start failed: " + agentIdOrError);
                        StopAgentAndLeaveChannel();  // Cleanup on failure
                        return;
                    }
                    
                    m_agentId = agentIdOrError;
                    m_isActive = true;
                    LOG_INFO("[MainFrm] Agent started with ID: " + agentIdOrError);
                    
                    // Update UI on main thread
                    this->PostMessage(WM_USER + 6, 0, 0);
                }
            );
        }
    );
}

// ============================================================================
// Manager Setup
// ============================================================================

void CMainFrame::SetupManagers()
{
    LOG_INFO("[MainFrm] SetupManagers called");
    
    // Create RTC Engine with direct delegate pattern
    agora::rtc::IRtcEngine* rtcEngine = m_rtcManager.CreateRtcEngine(this);
    if (!rtcEngine) {
        LOG_ERROR("[MainFrm] Failed to create RTC Engine");
        return;
    }
    
    LOG_INFO("[MainFrm] RTC Engine created successfully");
    
    // Initialize RTM Manager
    RtmManagerConfig rtmConfig;
    rtmConfig.appId = KeyCenter::AGORA_APP_ID;
    rtmConfig.userId = std::to_string(m_userUid);
    
    if (!m_rtmManager.Initialize(rtmConfig)) {
        LOG_ERROR("[MainFrm] Failed to initialize RTM Manager");
        return;
    }
    
    m_rtmManager.SetEventHandler(this);  // Set external event handler for forwarding
    LOG_INFO("[MainFrm] RTM Manager initialized");
    
    // Initialize status labels
    UpdateMicStatus(false);
    UpdateChannelStatus(false, _T("Ready"));
    UpdateAgentStatus(_T("Not Started"));
}

void CMainFrame::InitializeConvoAIAPI()
{
    LOG_INFO("[MainFrm] InitializeConvoAIAPI called");
    
    if (m_convoAIAPI) {
        LOG_WARN("[MainFrm] ConvoAIAPI already initialized");
        return;
    }
    
    // Create ConversationalAI API instance (RAII with unique_ptr)
    m_convoAIAPI = std::make_unique<ConversationalAIAPI>(&m_rtmManager);
    m_convoAIAPI->AddHandler(this);
    
    LOG_INFO("[MainFrm] ConvoAIAPI created, handlers added");
    
    // Subscribe to channel messages through ConvoAIAPI
    m_convoAIAPI->SubscribeMessage(m_channelName, [this](int errorCode, const std::string& errorMsg) {
        // Safety check: ensure window is still valid
        if (!GetSafeHwnd()) {
            LOG_WARN("[MainFrm] Window destroyed, ignoring subscribe callback");
            return;
        }
        
        if (errorCode == 0) {
            LOG_INFO("[MainFrm] Subscribed to channel via ConvoAIAPI");
        } else {
            LOG_ERROR("[MainFrm] ❌ Failed to subscribe via ConvoAIAPI: " + errorMsg);
        }
    });
    
    LOG_INFO("[MainFrm] ConvoAIAPI initialized, subscription in progress");
}

// ============================================================================
// agora::rtc::IRtcEngineEventHandler Implementation (Direct SDK Callbacks)
// ============================================================================

void CMainFrame::onJoinChannelSuccess(const char* channel, agora::rtc::uid_t uid, int elapsed)
{
    LOG_INFO("[MainFrm] RTC joined channel: " + std::string(channel) + ", uid: " + std::to_string(uid));
    
    // Update UI on main thread
    this->PostMessage(WM_USER + 10, 0, 0);
}

void CMainFrame::onLeaveChannel(const agora::rtc::RtcStats& stats)
{
    LOG_INFO("[MainFrm] RTC left channel, duration: " + std::to_string(stats.duration));
    
    // Update UI on main thread
    this->PostMessage(WM_USER + 11, 0, 0);
}

void CMainFrame::onUserJoined(agora::rtc::uid_t uid, int elapsed)
{
    LOG_INFO("[MainFrm] User joined: " + std::to_string(uid));
    
    // Check if it's the agent
    if (uid == m_agentUid && m_isActive) {
        LOG_INFO("[MainFrm] Agent joined RTC channel");
        
        // Update UI on main thread
        this->PostMessage(WM_USER + 12, 0, 0);
    }
}

void CMainFrame::onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE reason)
{
    LOG_INFO("[MainFrm] User offline: " + std::to_string(uid) + ", reason: " + std::to_string(reason));
    
    // Check if it's the agent
    if (uid == m_agentUid && m_isActive) {
        LOG_INFO("[MainFrm] ⚠️ Agent left RTC channel");
        
        // Update UI on main thread
        this->PostMessage(WM_USER + 13, 0, 0);
    }
}

void CMainFrame::onTokenPrivilegeWillExpire(const char* token)
{
    LOG_WARN("[MainFrm] RTC token will expire, need to renew");
    // TODO: Implement token renewal
}

void CMainFrame::onError(int err, const char* msg)
{
    LOG_ERROR("[MainFrm] RTC error: " + std::to_string(err) + ", " + std::string(msg));
}

// ============================================================================
// IRtmManagerEventHandler Implementation
// ============================================================================

void CMainFrame::onLoginSuccess(const char* userId)
{
    LOG_INFO("[MainFrm] RTM login success: " + std::string(userId));
}

void CMainFrame::onLoginFailed(int errorCode, const char* errorMessage)
{
    LOG_ERROR("[MainFrm] RTM login failed: " + std::to_string(errorCode) + ", " + std::string(errorMessage));
}

void CMainFrame::onLogout()
{
    LOG_INFO("[MainFrm] RTM logout");
}

void CMainFrame::onMessageReceived(const char* message, const char* fromUserId)
{
    LOG_INFO("[MainFrm] RTM message received from: " + std::string(fromUserId));
    
    // Pass message to ConvoAIAPI for parsing
    if (m_convoAIAPI) {
        m_convoAIAPI->HandleMessage(message, fromUserId);
    }
}

void CMainFrame::onConnectionStateChanged(agora::rtm::RTM_LINK_STATE state, agora::rtm::RTM_LINK_STATE_CHANGE_REASON reason)
{
    LOG_INFO("[MainFrm] RTM connection state changed: " + std::to_string((int)state));
}

// ============================================================================
// IConversationalAIAPIEventHandler Implementation
// ============================================================================

void CMainFrame::OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript)
{
    // Convert UTF-8 to GBK for log display
    std::string displayText = StringUtils::Utf8ToGBK(transcript.text);
    LOG_INFO("[MainFrm] Transcript updated: " + displayText);
    
    // Find or add transcript (already on correct thread or will be marshalled)
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
        
    // Update UI
    this->PostMessage(WM_USER + 20, 0, 0);
}

void CMainFrame::OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event)
{
    LOG_INFO("[MainFrm] Agent state changed: " + std::to_string((int)event.state));
    
    // Update status label on main thread
    this->PostMessage(WM_USER + 21, (WPARAM)event.state, 0);
}

// ============================================================================
// Windows Message Handlers (for async callbacks)
// ============================================================================

LRESULT CMainFrame::OnTokenGenerationFailed(WPARAM wParam, LPARAM lParam)
{
    UpdateChannelStatus(false, _T("Token failed"));
    UpdateAgentStatus(_T("Failed"));
    m_btnStartStop.EnableWindow(TRUE);  // Re-enable button on failure
    return 0;
}

LRESULT CMainFrame::OnAgentStopped(WPARAM wParam, LPARAM lParam)
{
    bool success = (wParam != 0);
    
    if (success) {
        UpdateAgentStatus(_T("Stopped"));
        m_agentId.clear();
    } else {
        UpdateAgentStatus(_T("Stop failed"));
    }
    
    return 0;
}

LRESULT CMainFrame::OnRTMLoginSuccess(WPARAM wParam, LPARAM lParam)
{
    UpdateChannelStatus(true, _T("Connected"));
    UpdateUIState(false);
    return 0;
}

LRESULT CMainFrame::OnAgentStartFailed(WPARAM wParam, LPARAM lParam)
{
    UpdateAgentStatus(_T("Start failed"));
    m_btnStartStop.EnableWindow(TRUE);  // Re-enable button on failure
    return 0;
}

LRESULT CMainFrame::OnAgentStarted(WPARAM wParam, LPARAM lParam)
{
    m_btnStartStop.SetWindowText(_T("Stop Agent"));
    m_btnStartStop.EnableWindow(TRUE);  // Re-enable button after successful start
    UpdateAgentStatus(_T("Launching..."));
    UpdateUIState(false);
    return 0;
}

LRESULT CMainFrame::OnRTCJoinSuccess(WPARAM wParam, LPARAM lParam)
{
    LOG_INFO("[MainFrm] RTC join success UI update");
    return 0;
}

LRESULT CMainFrame::OnRTCLeave(WPARAM wParam, LPARAM lParam)
{
    LOG_INFO("[MainFrm] RTC leave UI update");
    return 0;
}

LRESULT CMainFrame::OnAgentJoined(WPARAM wParam, LPARAM lParam)
{
    if (m_isActive) {
        UpdateAgentStatus(_T("Connected"));
        LOG_INFO("[MainFrm] Agent joined UI update - Status set to 'Connected'");
    }
    return 0;
}

LRESULT CMainFrame::OnAgentLeft(WPARAM wParam, LPARAM lParam)
{
    if (m_isActive) {
        UpdateAgentStatus(_T("Disconnected"));
        LOG_WARN("[MainFrm] Agent left UI update");
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
        case AgentState::Idle:
            stateText = _T("Idle");
            break;
        case AgentState::Silent:
            stateText = _T("Silent");
            break;
        case AgentState::Listening:
            stateText = _T("Listening");
            break;
        case AgentState::Thinking:
            stateText = _T("Thinking");
            break;
        case AgentState::Speaking:
            stateText = _T("Speaking");
            break;
        default:
            stateText = _T("Unknown");
            break;
    }
    
    UpdateAgentStatus(stateText);
    return 0;
}

// ============================================================================
// Helper Methods
// ============================================================================

std::string CMainFrame::GenerateRandomChannelName()
{
    int randomNumber = rand() % 9000 + 1000;
    return "channel_windows_" + std::to_string(randomNumber);
}
