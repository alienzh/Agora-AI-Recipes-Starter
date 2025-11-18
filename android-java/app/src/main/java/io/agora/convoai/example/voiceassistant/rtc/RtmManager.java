package io.agora.convoai.example.voiceassistant.rtc;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import io.agora.convoai.example.voiceassistant.KeyCenter;
import io.agora.rtm.ErrorInfo;
import io.agora.rtm.LinkStateEvent;
import io.agora.rtm.PresenceEvent;
import io.agora.rtm.ResultCallback;
import io.agora.rtm.RtmClient;
import io.agora.rtm.RtmConfig;
import io.agora.rtm.RtmConstants;
import io.agora.rtm.RtmEventListener;
import java.util.ArrayList;
import java.util.List;

/**
 * RTM Manager - Manages RTM client lifecycle and operations
 */
public class RtmManager implements RtmEventListener {
    private static final String TAG = "RtmManager";

    private static volatile boolean isRtmLogin = false;
    private static volatile boolean isLoggingIn = false;
    private static volatile RtmClient rtmClient;
    private static final List<IRtmManagerListener> listeners = new ArrayList<>();
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    /**
     * Interface for RTM manager listeners
     */
    public interface IRtmManagerListener {
        /**
         * RTM failed, need login
         */
        void onFailed();

        /**
         * Token will expire, need renew token
         * @param channelName Channel name
         */
        void onTokenPrivilegeWillExpire(String channelName);

        /**
         * Presence event
         * @param event Presence event
         */
        void onPresenceEvent(PresenceEvent event);
    }

    /**
     * Create RTM client
     * @param uid User ID
     * @return RtmClient instance
     */
    public static RtmClient createRtmClient(int uid) {
        if (rtmClient != null) {
            return rtmClient;
        }

        RtmConfig rtmConfig = new RtmConfig.Builder(KeyCenter.AGORA_APP_ID, String.valueOf(uid)).build();
        try {
            rtmClient = RtmClient.create(rtmConfig);
            rtmClient.addEventListener(new RtmManager());
            callMessagePrint("RTM createRtmClient success");
        } catch (Exception e) {
            e.printStackTrace();
            callMessagePrint("RTM createRtmClient error " + e.getMessage());
        }
        return rtmClient;
    }

    /**
     * Add listener
     * @param listener IRtmManagerListener
     */
    public static void addListener(IRtmManagerListener listener) {
        synchronized (listeners) {
            if (!listeners.contains(listener)) {
                listeners.add(listener);
            }
        }
    }

    /**
     * Remove listener
     * @param listener IRtmManagerListener
     */
    public static void removeListener(IRtmManagerListener listener) {
        synchronized (listeners) {
            listeners.remove(listener);
        }
    }

    /**
     * Login RTM
     * @param rtmToken RTM token
     * @param completion Completion callback
     */
    public static void login(String rtmToken, RtmLoginCallback completion) {
        callMessagePrint("Starting RTM login");

        if (isLoggingIn) {
            completion.onResult(new Exception("Login already in progress"));
            callMessagePrint("Login already in progress");
            return;
        }

        if (isRtmLogin) {
            completion.onResult(null); // Already logged in
            callMessagePrint("Already logged in");
            return;
        }

        if (rtmClient == null) {
            completion.onResult(new Exception("RTM client not initialized"));
            callMessagePrint("RTM client not initialized");
            return;
        }

        isLoggingIn = true;
        callMessagePrint("Performing logout to ensure clean environment before login");

        // Force logout first (synchronous flag update)
        isRtmLogin = false;
        rtmClient.logout(new ResultCallback<Void>() {
            @Override
            public void onSuccess(Void responseInfo) {
                callMessagePrint("Logout completed, starting login");
                performLogin(rtmClient, rtmToken, completion);
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                callMessagePrint("Logout failed but continuing with login: " + errorInfoStr(errorInfo));
                performLogin(rtmClient, rtmToken, completion);
            }
        });
    }

    private static void performLogin(RtmClient rtmClient, String rtmToken, RtmLoginCallback completion) {
        rtmClient.login(rtmToken, new ResultCallback<Void>() {
            @Override
            public void onSuccess(Void p0) {
                isRtmLogin = true;
                isLoggingIn = false;
                callMessagePrint("RTM login successful");
                completion.onResult(null);
            }

            @Override
            public void onFailure(ErrorInfo errorInfo) {
                isRtmLogin = false;
                isLoggingIn = false;
                callMessagePrint("RTM token login failed: " + errorInfoStr(errorInfo));
                completion.onResult(new Exception(String.valueOf(errorInfo != null ? errorInfo.getErrorCode() : -1)));
            }
        });
    }

    /**
     * Logout RTM
     */
    public static void logout() {
        callMessagePrint("RTM start logout");
        if (rtmClient != null) {
            rtmClient.logout(new ResultCallback<Void>() {
                @Override
                public void onSuccess(Void responseInfo) {
                    isRtmLogin = false;
                    callMessagePrint("RTM logout successful");
                }

                @Override
                public void onFailure(ErrorInfo errorInfo) {
                    callMessagePrint("RTM logout failed: " + errorInfoStr(errorInfo));
                    // Still mark as logged out since we attempted logout
                    isRtmLogin = false;
                }
            });
        }
    }

    /**
     * Renew RTM token
     * @param rtmToken New RTM token
     * @param completion Completion callback
     */
    public static void renewToken(String rtmToken, RtmLoginCallback completion) {
        callMessagePrint("RTM start renewToken");
        if (!isRtmLogin) {
            callMessagePrint("RTM not logged in, performing login instead of token renewal");
            login(rtmToken, completion);
            return;
        }

        if (rtmClient != null) {
            rtmClient.renewToken(rtmToken, new ResultCallback<Void>() {
                @Override
                public void onSuccess(Void responseInfo) {
                    callMessagePrint("RTM renewToken successfully");
                    completion.onResult(null);
                }

                @Override
                public void onFailure(ErrorInfo errorInfo) {
                    callMessagePrint("RTM renewToken failed: " + errorInfoStr(errorInfo));
                    isRtmLogin = false;
                    completion.onResult(new Exception(String.valueOf(errorInfo != null ? errorInfo.getErrorCode() : -1)));
                }
            });
        }
    }

    /**
     * Destroy RTM client
     */
    public static void destroy() {
        callMessagePrint("RTM destroy");

        // Clear listeners
        synchronized (listeners) {
            listeners.clear();
        }

        // Logout and cleanup
        isRtmLogin = false;
        isLoggingIn = false;

        if (rtmClient != null) {
            try {
                rtmClient.removeEventListener(new RtmManager());
                rtmClient.logout(new ResultCallback<Void>() {
                    @Override
                    public void onSuccess(Void responseInfo) {
                        callMessagePrint("RTM logout successful during destroy");
                    }

                    @Override
                    public void onFailure(ErrorInfo errorInfo) {
                        callMessagePrint("RTM logout failed during destroy: " + errorInfoStr(errorInfo));
                    }
                });
            } catch (Exception e) {
                callMessagePrint("Error during RTM cleanup: " + e.getMessage());
            }
        }

        rtmClient = null;

        try {
            RtmClient.release();
        } catch (Exception e) {
            callMessagePrint("Error releasing RTM client: " + e.getMessage());
        }
    }

    @Override
    public void onLinkStateEvent(LinkStateEvent event) {
        if (event == null) {
            return;
        }

        RtmConstants.RtmLinkState currentState = event.getCurrentState();
        callMessagePrint("RTM link state changed: " + currentState);

        if (currentState == RtmConstants.RtmLinkState.CONNECTED) {
            callMessagePrint("RTM connected successfully");
            isRtmLogin = true;
        } else if (currentState == RtmConstants.RtmLinkState.FAILED) {
            callMessagePrint("RTM connection failed, need to re-login");
            isRtmLogin = false;
            isLoggingIn = false;
            mainHandler.post(() -> {
                synchronized (listeners) {
                    for (IRtmManagerListener listener : listeners) {
                        listener.onFailed();
                    }
                }
            });
        }
    }

    @Override
    public void onTokenPrivilegeWillExpire(String channelName) {
        callMessagePrint("RTM onTokenPrivilegeWillExpire " + channelName);
        mainHandler.post(() -> {
            synchronized (listeners) {
                for (IRtmManagerListener listener : listeners) {
                    listener.onTokenPrivilegeWillExpire(channelName);
                }
            }
        });
    }

    @Override
    public void onPresenceEvent(PresenceEvent event) {
        mainHandler.post(() -> {
            synchronized (listeners) {
                for (IRtmManagerListener listener : listeners) {
                    listener.onPresenceEvent(event);
                }
            }
        });
    }

    private static void callMessagePrint(String message) {
        Log.d(TAG, message);
    }

    private static String errorInfoStr(ErrorInfo errorInfo) {
        if (errorInfo == null) {
            return "null";
        }
        return errorInfo.getOperation() + " " + errorInfo.getErrorCode() + " " + errorInfo.getErrorReason();
    }

    /**
     * Callback interface for RTM login operations
     */
    public interface RtmLoginCallback {
        /**
         * Called when login operation completes
         * @param exception Exception if login failed, null if successful
         */
        void onResult(Exception exception);
    }
}

