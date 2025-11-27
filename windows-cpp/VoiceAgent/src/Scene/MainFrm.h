#pragma once

#ifndef __AFXWIN_H__
    #error "Include 'pch.h' before including this file for PCH"
#endif

#include <memory>
#include <string>
#include <vector>

// Forward declarations
class RtcManager;
class RtmManager;
class ConversationalAIAPI;

// Include necessary headers for interfaces
#include "../Managers/RtcManager.h"
#include "../Managers/RtmManager.h"
#include "../ConversationalAIAPI/ConversationalAIAPI.h"

// MainFrame - Main application window
// Two-panel layout: Left (controls) | Right (messages)
// Implements event handlers:
// - RTC: directly implements agora::rtc::IRtcEngineEventHandler (no internal forwarding)
// - RTM: implements IRtmManagerEventHandler (has internal forwarding in RtmManager)
// - ConversationalAI: implements IConversationalAIAPIEventHandler
class CMainFrame : public CFrameWnd, 
                   public agora::rtc::IRtcEngineEventHandler,
                   public IRtmManagerEventHandler,
                   public IConversationalAIAPIEventHandler
{
    DECLARE_DYNAMIC(CMainFrame)
    
public:
    CMainFrame() noexcept;
    virtual ~CMainFrame();
    
    // Overrides
    virtual BOOL PreCreateWindow(CREATESTRUCT& cs);
    
#ifdef _DEBUG
    virtual void AssertValid() const;
    virtual void Dump(CDumpContext& dc) const;
#endif

private:
    // UI Components
    
    // Left Panel (Control) - 220px width
    CStatic m_leftPanel;
    CEdit m_editChannel;
    CButton m_btnStartStop;         // Combined Start/Stop Agent button
    CButton m_btnMute;              // Mute button
    
    // Status labels (3 lines, title on left, detail on right)
    CStatic m_labelMicTitle;        // Line 1 title: "Microphone"
    CStatic m_labelMicDetail;       // Line 1 detail: "Active" / "Muted"
    CStatic m_labelChannelTitle;    // Line 2 title: "Channel"
    CStatic m_labelChannelDetail;   // Line 2 detail: "Connected" / "Disconnected"
    CStatic m_labelAgentTitle;      // Line 3 title: "Agent"
    CStatic m_labelAgentDetail;     // Line 3 detail: "Not Started" / "Connected"
    
    // Right Panel (Transcript)
    CStatic m_rightPanel;
    CListCtrl m_listMessages;       // Message list
    CStatic m_labelTranscriptCount; // Transcript count label
    CButton m_btnClear;             // Clear button
    
    // Fonts
    CFont m_normalFont;
    CFont m_boldFont;
    
    // Managers and API
    
    RtcManager& m_rtcManager;
    RtmManager& m_rtmManager;
    std::unique_ptr<ConversationalAIAPI> m_convoAIAPI;  // ConversationalAI API for transcript processing (RAII)
    
    // State Variables
    
    std::string m_channelName;
    bool m_isActive;     // Agent is active (joined channel + agent started)
    bool m_isMuted;
    
    // Tokens and IDs
    std::string m_token;
    std::string m_agentToken;
    std::string m_agentId;
    unsigned int m_userUid;
    unsigned int m_agentUid;
    
    // Message list data
    std::vector<Transcript> m_transcripts;
    
    // UI Constants
    
    static const int LEFT_PANEL_WIDTH = 220;
    static const int PANEL_SPACING = 1;
    static const int PADDING = 20;
    static const int BUTTON_HEIGHT = 32;
    static const int EDIT_HEIGHT = 24;
    
    // UI Setup Methods
    
    void SetupUI();
    void SetupLeftPanel(const CRect& rect);
    void SetupRightPanel(const CRect& rect);
    void UpdateUIState(bool idle);
    
    // Status update helpers
    void UpdateMicStatus(bool muted);
    void UpdateChannelStatus(bool connected, const CString& message = _T(""));
    void UpdateAgentStatus(const CString& message);
    
    // Button Actions
    
    void OnStartStopClicked();
    void OnMuteClicked();
    void OnClearClicked();
    
    // Business Logic Methods
    
    void SetupManagers();
    void InitializeConvoAIAPI();
    void JoinChannelAndStartAgent();
    void StopAgentAndLeaveChannel();
    /// Generate random channel name
    std::string GenerateRandomChannelName();
    void StartAgent();
    void UpdateTranscripts();
    
    // agora::rtc::IRtcEngineEventHandler Methods (direct SDK callbacks)
    
    void onJoinChannelSuccess(const char* channel, agora::rtc::uid_t uid, int elapsed) override;
    void onLeaveChannel(const agora::rtc::RtcStats& stats) override;
    void onUserJoined(agora::rtc::uid_t uid, int elapsed) override;
    void onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE reason) override;
    void onTokenPrivilegeWillExpire(const char* token) override;
    void onError(int err, const char* msg) override;
    
    // IRtmManagerEventHandler Methods (forwarded by RtmManager)
    
    void onLoginSuccess(const char* userId) override;
    void onLoginFailed(int errorCode, const char* errorMessage) override;
    void onLogout() override;
    void onMessageReceived(const char* message, const char* fromUserId) override;
    void onConnectionStateChanged(agora::rtm::RTM_LINK_STATE state, agora::rtm::RTM_LINK_STATE_CHANGE_REASON reason) override;
    
    // IConversationalAIAPIEventHandler Methods
    
    void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) override;
    void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) override;
    
    // Message Map
    
protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnSize(UINT nType, int cx, int cy);
    afx_msg void OnPaint();
    afx_msg void OnBnClickedJoinLeave();
    afx_msg void OnBnClickedStartAgent();
    afx_msg void OnBnClickedMute();
    afx_msg void OnBnClickedClear();
    
    // Custom message handlers for async callbacks
    afx_msg LRESULT OnTokenGenerationFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStopped(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTMLoginSuccess(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStartFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStarted(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTCJoinSuccess(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTCLeave(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentJoined(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentLeft(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnTranscriptUpdate(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStateUpdate(WPARAM wParam, LPARAM lParam);
    
    DECLARE_MESSAGE_MAP()
};
