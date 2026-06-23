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
        startWithAudioMuted:    false,
        startWithVideoMuted:    false,
        enableClosePage:        false,
        disableDeepLinking:     true,
        prejoinPageEnabled:     false,
        enableWelcomePage:      false,
        toolbarButtons:         [], // we use our own toolbar
        notifications:          [],
      },
      interfaceConfigOverwrite: {
        SHOW_JITSI_WATERMARK:    false,
        SHOW_BRAND_WATERMARK:    false,
        HIDE_INVITE_MORE_HEADER: true,
        TOOLBAR_ALWAYS_VISIBLE:  false,
        DISABLE_JOIN_LEAVE_NOTIFICATIONS: true,
      },
      userInfo: {
        displayName: user?.full_name || 'Student',
        email:       user?.email     || '',
      },
    };

    try {
      jitsiAPI.current = new window.JitsiMeetExternalAPI(domain, options);

      jitsiAPI.current.addListener('videoConferenceJoined', () => {
        setJoined(true);
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
    <div className="flex flex-col h-full bg-gray-900">
      {/* Lobby / pre-join */}
      {!joined && (
        <div className="flex-1 flex items-center justify-center p-6">
          <motion.div initial={{ opacity:0, scale:0.95 }} animate={{ opacity:1, scale:1 }}
            className="bg-gray-800 rounded-3xl border border-gray-700 shadow-2xl p-8 w-full max-w-md text-center">
            <div className="w-20 h-20 bg-gradient-to-br from-brand-600 to-brand-800 rounded-2xl flex items-center justify-center mx-auto mb-5 shadow-glow">
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

      {/* Jitsi container — always rendered so it can be initialized */}
      <div
        ref={jitsiContainer}
        className={clsx('flex-1 relative', !joined && 'hidden')}
        style={{ minHeight: 0 }}
      />

      {/* Custom control bar (shown after joining) */}
      <AnimatePresence>
        {joined && (
          <motion.div
            initial={{ y: 80, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: 80, opacity: 0 }}
            className="flex-shrink-0 bg-gray-900/95 backdrop-blur border-t border-gray-700 px-4 py-3"
          >
            <div className="flex items-center justify-center gap-2 sm:gap-3 flex-wrap">
              {/* Mic */}
              <ControlBtn onClick={toggleMic} active={!muted} activeColor="green" inactiveColor="red" label={muted ? 'Unmute' : 'Mute'}>
                {muted ? <MicOff size={18}/> : <Mic size={18}/>}
              </ControlBtn>

              {/* Camera */}
              <ControlBtn onClick={toggleCam} active={!camOff} activeColor="green" inactiveColor="red" label={camOff ? 'Start Video' : 'Stop Video'}>
                {camOff ? <VideoOff size={18}/> : <Video size={18}/>}
              </ControlBtn>

              {/* Screen share */}
              <ControlBtn onClick={toggleShare} active={sharing} activeColor="blue" label="Share Screen">
                {sharing ? <MonitorOff size={18}/> : <Monitor size={18}/>}
              </ControlBtn>

              {/* Raise hand */}
              <ControlBtn onClick={toggleHand} active={handUp} activeColor="amber" label={handUp ? 'Lower Hand' : 'Raise Hand'}>
                <Hand size={18}/>
              </ControlBtn>

              {/* Chat */}
              <ControlBtn onClick={toggleChat} active={showChat} activeColor="brand" label="Chat">
                <MessageSquare size={18}/>
              </ControlBtn>

              {/* Participants count */}
              <div className="flex items-center gap-1.5 px-3 py-2 bg-gray-700 rounded-xl text-gray-300 text-sm">
                <Users size={15}/>
                <span>{participants.length + 1}</span>
              </div>

              {/* Copy link */}
              <button onClick={copyLink} className="hidden sm:flex items-center gap-1.5 px-3 py-2 bg-gray-700 hover:bg-gray-600 rounded-xl text-gray-300 text-sm transition-all">
                {copied ? <Check size={15} className="text-green-400"/> : <Copy size={15}/>}
                <span className="hidden md:inline">Invite</span>
              </button>

              {/* Leave */}
              <button onClick={leaveMeeting}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-semibold transition-all ml-2">
                <PhoneOff size={16}/> <span className="hidden sm:inline">Leave</span>
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

function ControlBtn({ onClick, active, activeColor, inactiveColor, label, children }) {
  const colors = {
    green:  active ? 'bg-green-600 hover:bg-green-700 text-white'   : (inactiveColor==='red' ? 'bg-red-600 hover:bg-red-700 text-white' : 'bg-gray-700 hover:bg-gray-600 text-gray-300'),
    blue:   active ? 'bg-blue-600 hover:bg-blue-700 text-white'     : 'bg-gray-700 hover:bg-gray-600 text-gray-300',
    amber:  active ? 'bg-amber-500 hover:bg-amber-600 text-white'   : 'bg-gray-700 hover:bg-gray-600 text-gray-300',
    brand:  active ? 'bg-brand-600 hover:bg-brand-700 text-white'   : 'bg-gray-700 hover:bg-gray-600 text-gray-300',
    red:    active ? 'bg-gray-700 hover:bg-gray-600 text-gray-300'  : 'bg-red-600 hover:bg-red-700 text-white',
  };
  return (
    <button onClick={onClick} title={label}
      className={clsx('flex flex-col items-center gap-0.5 px-3 py-2 rounded-xl transition-all', colors[activeColor] || 'bg-gray-700 hover:bg-gray-600 text-gray-300')}>
      {children}
      <span className="text-[10px] hidden sm:block">{label}</span>
    </button>
  );
}
