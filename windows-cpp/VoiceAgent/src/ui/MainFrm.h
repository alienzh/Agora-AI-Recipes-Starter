#pragma once

#ifndef __AFXWIN_H__
    #error "Include 'pch.h' before including this file for PCH"
#endif

#include <memory>
#include <string>
#include <vector>

#include "../rtc/RtcManager.h"
#include "../rtm/RtmManager.h"
#include "../ConversationalAIAPI/ConversationalAIAPI.h"

class CMainFrame : public CFrameWnd, 
                   public agora::rtc::IRtcEngineEventHandler,
                   public IRtmManagerEventHandler,
                   public IConversationalAIAPIEventHandler
{
    DECLARE_DYNAMIC(CMainFrame)
    
public:
    CMainFrame() noexcept;
    virtual ~CMainFrame();
    virtual BOOL PreCreateWindow(CREATESTRUCT& cs);
    
#ifdef _DEBUG
    virtual void AssertValid() const;
    virtual void Dump(CDumpContext& dc) const;
#endif

private:
    // UI Components - Top Panel (Transcript)
    CStatic m_topPanel;
    CListCtrl m_listMessages;
    CStatic m_labelAgentStatus;
    
    // UI Components - Log Panel (right side)
    CStatic m_logPanel;
    CListCtrl m_listLog;
    
    // UI Components - Bottom Panel (Control)
    CStatic m_bottomPanel;
    CButton m_btnStart;
    CButton m_btnStop;
    CButton m_btnMute;
    
    // Fonts
    CFont m_normalFont;
    CFont m_smallFont;
    
    // Agora SDK
    RtcManager& m_rtcManager;
    RtmManager& m_rtmManager;
    std::unique_ptr<ConversationalAIAPI> m_convoAIAPI;
    
    // State
    std::string m_channelName;
    std::string m_token;
    std::string m_agentToken;
    std::string m_agentId;
    bool m_isActive;
    bool m_isMuted;
    std::vector<Transcript> m_transcripts;
    
    // Constants
    unsigned int m_userUid;
    unsigned int m_agentUid;
    static const int BOTTOM_PANEL_HEIGHT = 70;
    static const int LOG_PANEL_WIDTH = 200;
    static const int PADDING = 20;
    static const int BUTTON_HEIGHT = 44;
    
    // UI Setup
    void SetupUI();
    void SetupTopPanel();
    void SetupLogPanel();
    void SetupBottomPanel();
    void LayoutPanels();
    
    // UI Helpers
    void UpdateAgentStatus(const CString& message);
    void ShowIdleButtons();
    void ShowActiveButtons();
    void UpdateTranscripts();
    void LogToView(const CString& message);
    
    // SDK Setup
    void SetupSDK();
    void InitializeRTC();
    void InitializeRTM();
    void InitializeConvoAI();
    
    // Session Management
    void StartSession();
    void StopSession();
    void JoinRTCChannel(const std::string& token);
    void LoginRTM(const std::string& token);
    void StartAgent();
    
    // Helpers
    std::string GenerateRandomChannelName();
    
    // RTC Callbacks
    void onJoinChannelSuccess(const char* channel, agora::rtc::uid_t uid, int elapsed) override;
    void onLeaveChannel(const agora::rtc::RtcStats& stats) override;
    void onUserJoined(agora::rtc::uid_t uid, int elapsed) override;
    void onUserOffline(agora::rtc::uid_t uid, agora::rtc::USER_OFFLINE_REASON_TYPE reason) override;
    void onTokenPrivilegeWillExpire(const char* token) override;
    void onError(int err, const char* msg) override;
    
    // RTM Callbacks
    void onLoginSuccess(const char* userId) override;
    void onLoginFailed(int errorCode, const char* errorMessage) override;
    void onLogout() override;
    void onMessageReceived(const char* message, const char* fromUserId) override;
    void onConnectionStateChanged(agora::rtm::RTM_LINK_STATE state, agora::rtm::RTM_LINK_STATE_CHANGE_REASON reason) override;
    
    // ConvoAI Callbacks
    void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) override;
    void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) override;
    
protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnSize(UINT nType, int cx, int cy);
    afx_msg void OnStartClicked();
    afx_msg void OnStopClicked();
    afx_msg void OnMuteClicked();
    
    // Async message handlers
    afx_msg LRESULT OnTokenFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTMLoginSuccess(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnRTMLoginFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStarted(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStartFailed(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentJoined(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentLeft(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnTranscriptUpdate(WPARAM wParam, LPARAM lParam);
    afx_msg LRESULT OnAgentStateUpdate(WPARAM wParam, LPARAM lParam);
    
    DECLARE_MESSAGE_MAP()
};
