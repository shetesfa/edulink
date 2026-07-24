import React, { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Mic, MicOff, Video, VideoOff, Monitor, MonitorOff,
  Hand, PhoneOff, Users, MessageSquare, Settings,
  Copy, Check, Loader2, ArrowLeft,
} from 'lucide-react';
import { meetingAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import toast from 'react-hot-toast';
import clsx from 'clsx';

export default function VideoMeeting() {
  const { id }    = useParams();
  const navigate  = useNavigate();
  const { user }  = useAuthStore();

  const [meeting, setMeeting]   = useState(null);
  const [tokenData, setToken]   = useState(null);
  const [loading, setLoading]   = useState(true);
  const [joined, setJoined]     = useState(false);
  const [error, setError]       = useState(null);

  // Controls state (mirrors Jitsi API state)
  const [muted,    setMuted]    = useState(false);
  const [camOff,   setCamOff]   = useState(false);
  const [sharing,  setSharing]  = useState(false);
  const [handUp,   setHandUp]   = useState(false);
  const [copied,   setCopied]   = useState(false);
  const [showChat, setShowChat] = useState(false);
  const [participants, setParticipants] = useState([]);

  const jitsiContainer = useRef(null);
  const jitsiAPI       = useRef(null);

  useEffect(() => {
    Promise.all([meetingAPI.get(id), meetingAPI.token(id)])
      .then(([{ data: md }, { data: td }]) => {
        setMeeting(md.meeting);
        setToken(td);
      })
      .catch(() => setError('Meeting not found or you do not have access.'))
      .finally(() => setLoading(false));
  }, [id]);

  const joinMeeting = async () => {
    if (!tokenData || !jitsiContainer.current) return;

    // Load Jitsi script if not already loaded
    if (!window.JitsiMeetExternalAPI) {
      await loadJitsiScript();
    }

    const domain   = tokenData.domain || 'meet.jit.si';
    const roomName = tokenData.room_id;

    const options = {
      roomName,
      parentNode: jitsiContainer.current,
      width:      '100%',
      height:     '100%',
      jwt:        tokenData.token || undefined,
      configOverwrite: {
        startWithAudioMuted:    true,
        startWithVideoMuted:    true,
        enableClosePage:        false,
        disableDeepLinking:     true,
        prejoinPageEnabled:     false,
        enableWelcomePage:      false,
        hideConferenceSubject:  true,
        disableInviteFunctions: true,
      },
      interfaceConfigOverwrite: {
        SHOW_JITSI_WATERMARK:    false,
        SHOW_BRAND_WATERMARK:    false,
        SHOW_POWERED_BY:         false,
        SHOW_PROMO_CONTAINER:    false,
        SHOW_WATERMARK_FOR_GUEST:false,
        HIDE_INVITE_MORE_HEADER: true,
      },
      userInfo: {
        displayName: user?.full_name || 'Student',
        email:       user?.email     || '',
      },
    };

    try {
      setJoined(true);
      jitsiAPI.current = new window.JitsiMeetExternalAPI(domain, options);

      jitsiAPI.current.addListener('videoConferenceJoined', () => {
        meetingAPI.start(id).catch(() => {});
      });

      jitsiAPI.current.addListener('videoConferenceLeft', () => {
        meetingAPI.end(id).catch(() => {});
        navigate(-1);
      });

      jitsiAPI.current.addListener('participantJoined', () => {
        jitsiAPI.current.getParticipantsInfo().then(setParticipants).catch(() => {});
      });

      jitsiAPI.current.addListener('participantLeft', () => {
        jitsiAPI.current.getParticipantsInfo().then(setParticipants).catch(() => {});
      });

      jitsiAPI.current.addListener('audioMuteStatusChanged', ({ muted: m }) => setMuted(m));
      jitsiAPI.current.addListener('videoMuteStatusChanged', ({ muted: m }) => setCamOff(m));
      jitsiAPI.current.addListener('screenSharingStatusChanged', ({ on }) => setSharing(on));
    } catch (err) {
      setError('Failed to connect to meeting. Please try again.');
    }
  };

  const loadJitsiScript = () => new Promise((resolve, reject) => {
    const script  = document.createElement('script');
    script.src    = 'https://meet.jit.si/external_api.js';
    script.onload = resolve;
    script.onerror= reject;
    document.head.appendChild(script);
  });

  // Controls
  const toggleMic     = () => { jitsiAPI.current?.executeCommand('toggleAudio');         setMuted((m) => !m); };
  const toggleCam     = () => { jitsiAPI.current?.executeCommand('toggleVideo');         setCamOff((c) => !c); };
  const toggleShare   = () => { jitsiAPI.current?.executeCommand('toggleShareScreen');   setSharing((s) => !s); };
  const toggleHand    = () => { jitsiAPI.current?.executeCommand('toggleRaiseHand');     setHandUp((h) => !h); };
  const toggleChat    = () => { jitsiAPI.current?.executeCommand('toggleChat');          setShowChat((c) => !c); };
  const leaveMeeting  = () => { jitsiAPI.current?.executeCommand('hangup'); navigate(-1); };

  const copyLink = () => {
    const link = `${window.location.origin}/meetings/${id}`;
    navigator.clipboard.writeText(link);
    setCopied(true); toast.success('Meeting link copied!');
    setTimeout(() => setCopied(false), 2000);
  };

  useEffect(() => {
    return () => { jitsiAPI.current?.dispose(); };
  }, []);

  if (loading) return (
    <div className="flex items-center justify-center h-full bg-gray-900">
      <div className="text-center text-white">
        <div className="w-12 h-12 border-4 border-brand-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"/>
        <p className="text-gray-400">Loading meeting…</p>
      </div>
    </div>
  );

  if (error) return (
    <div className="flex items-center justify-center h-full bg-gray-900">
      <div className="text-center text-white max-w-sm">
        <div className="w-16 h-16 bg-red-900/40 rounded-full flex items-center justify-center mx-auto mb-4">
          <Video size={28} className="text-red-400"/>
        </div>
        <h2 className="font-display font-bold text-xl mb-2">Can't join meeting</h2>
        <p className="text-gray-400 text-sm mb-5">{error}</p>
        <button onClick={() => navigate(-1)} className="flex items-center gap-2 mx-auto px-5 py-2.5 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-sm font-semibold transition-all">
          <ArrowLeft size={15}/> Go Back
        </button>
      </div>
    </div>
  );

  return (
    <div className="w-screen h-screen flex flex-col bg-gray-900 overflow-hidden">
      {/* Custom Top Header (shown after joining) */}
      {joined && (
        <div className="bg-gray-800 border-b border-gray-700 px-6 py-3 flex items-center justify-between text-white z-10">
          <div className="flex items-center gap-3">
            <button onClick={leaveMeeting} className="p-2 hover:bg-gray-700 rounded-lg text-gray-400 hover:text-white transition-colors">
              <ArrowLeft size={20} />
            </button>
            <div>
              <h1 className="font-semibold text-sm">{meeting?.title}</h1>
              <p className="text-xs text-gray-400">{meeting?.class?.name || 'Class Meeting'}</p>
            </div>
          </div>
          <button
            onClick={copyLink}
            className="flex items-center gap-2 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-xl text-xs font-semibold transition-all"
          >
            {copied ? <Check size={14} className="text-green-400"/> : <Copy size={14}/>}
            {copied ? 'Copied!' : 'Copy Invite Link'}
          </button>
        </div>
      )}

      {/* Lobby / pre-join */}
      {!joined && (
        <div className="flex-1 flex items-center justify-center p-6">
          <motion.div initial={{ opacity:0, scale:0.95 }} animate={{ opacity:1, scale:1 }}
            className="bg-gray-800 rounded-3xl border border-gray-700 shadow-2xl p-8 w-full max-w-md text-center">
            <div className="w-20 h-20 bg-brand-gradient-dark rounded-2xl flex items-center justify-center mx-auto mb-5 shadow-glow">
              <Video size={36} className="text-white"/>
            </div>
            <h2 className="font-display font-bold text-2xl text-white mb-1">{meeting?.title}</h2>
            <p className="text-gray-400 text-sm mb-6">
              Hosted by {meeting?.host?.full_name}
              {meeting?.class && ` · ${meeting.class.name}`}
            </p>

            <div className="bg-gray-700/50 rounded-2xl p-4 mb-6 space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Room ID</span>
                <code className="text-brand-400 font-mono text-xs bg-gray-700 px-2 py-1 rounded">{meeting?.room_id?.slice(0,20)}…</code>
              </div>
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-400">Status</span>
                <span className={clsx('text-xs font-semibold px-2 py-0.5 rounded-full',
                  meeting?.status === 'live' ? 'bg-green-900/50 text-green-400' :
                  meeting?.status === 'scheduled' ? 'bg-blue-900/50 text-blue-400' : 'bg-gray-600 text-gray-400')}>
                  {meeting?.status === 'live' ? '🔴 Live' : meeting?.status === 'scheduled' ? '⏰ Scheduled' : 'Ended'}
                </span>
              </div>
            </div>

            <div className="flex flex-col gap-3">
              <button onClick={joinMeeting}
                className="w-full py-3 bg-brand-600 hover:bg-brand-700 text-white font-semibold rounded-xl transition-all text-sm flex items-center justify-center gap-2">
                <Video size={16}/> Join Meeting
              </button>
              <button onClick={copyLink}
                className="w-full py-3 border border-gray-600 hover:bg-gray-700 text-gray-300 rounded-xl transition-all text-sm flex items-center justify-center gap-2">
                {copied ? <Check size={15}/> : <Copy size={15}/>} Copy Meeting Link
              </button>
              <button onClick={() => navigate(-1)} className="text-gray-500 hover:text-gray-300 text-sm flex items-center justify-center gap-1 transition-colors">
                <ArrowLeft size={14}/> Cancel
              </button>
            </div>
          </motion.div>
        </div>
      )}

      <div
        ref={jitsiContainer}
        className={clsx('flex-1 relative w-full h-full', !joined && 'hidden')}
        style={{ minHeight: 0 }}
      />
    </div>
  );
}
