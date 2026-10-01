#pragma once
#include <atomic>
#include <cmath>
namespace droneAudio {
inline std::atomic<float> volume{0.5f};
inline void run(const fs::path& root,const std::atomic<bool>& stop){
    constexpr int frames=1024,rate=48000,count=3;
    WAVEFORMATEX format{};format.wFormatTag=WAVE_FORMAT_PCM;format.nChannels=2;
    format.nSamplesPerSec=rate;format.wBitsPerSample=16;format.nBlockAlign=4;format.nAvgBytesPerSec=rate*4;
    HWAVEOUT device=nullptr;
    if(waveOutOpen(&device,WAVE_MAPPER,&format,0,0,CALLBACK_NULL)!=MMSYSERR_NOERROR){
        std::cerr<<"Drone audio: output unavailable; flight input continues.\n";return;
    }
    std::cerr<<"Drone audio: output ready (48 kHz stereo).\n";
    std::array<std::array<short,frames*2>,count> samples{};
    std::array<WAVEHDR,count> buffers{};
    for(int b=0;b<count;++b){buffers[b].lpData=reinterpret_cast<LPSTR>(samples[b].data());buffers[b].dwBufferLength=frames*4;
        waveOutPrepareHeader(device,&buffers[b],sizeof(WAVEHDR));}
    double phase[4]={0,0.17,0.43,0.79},rpm=0,envelope=0,filteredNoise=0;
    unsigned noise=0x51f0ac31;ULONGLONG lastChange=0,nextStateRead=0;std::string lastSeq;
    {std::ifstream previous(root/L"audio.txt");int version=0;previous>>version>>lastSeq;}
    double target=0;bool enabled=false;
    while(!stop){
        const auto now=GetTickCount64();
        // Lua publishes active audio at 25 Hz; state polling is independent of
        // the 4 ms buffer-service loop so queued audio still fills on time.
        if(now>=nextStateRead){
            nextStateRead=now+20;
            int version=0,active=0;std::string seq;double thrust=0;
            std::ifstream state(root/L"audio.txt");
            if(state>>version>>seq>>active>>thrust && version==1 && std::isfinite(thrust) && thrust>=0 && thrust<=1){
                if(seq!=lastSeq){lastSeq=seq;lastChange=GetTickCount64();}
                target=thrust;enabled=active==1;
            }
        }
        if(GetTickCount64()-lastChange>350)enabled=false;
        const bool audible=enabled&&volume.load()>0;
        const double targetRpm=85+450*std::sqrt(target);
        const double targetEnvelope=audible?(0.12+0.88*std::sqrt(target))*volume.load():0;
        // Once the fade is silent, let queued buffers drain. No oscillator work
        // or 250 Hz disk polling while walking around or when the game is closed.
        if(!audible&&envelope<0.00001){envelope=0;Sleep(50);continue;}
        for(int b=0;b<count;++b){
            auto& buffer=buffers[b];
            if((buffer.dwFlags&WHDR_INQUEUE)!=0)continue;
            for(int i=0;i<frames;++i){
                rpm+=(targetRpm-rpm)*0.0004;envelope+=(targetEnvelope-envelope)*0.001;
                double left=0,right=0;
                for(int motor=0;motor<4;++motor){
                    const double detune=1+(motor-1.5)*0.007;
                    phase[motor]+=rpm*detune/rate;phase[motor]-=std::floor(phase[motor]);
                    const double a=phase[motor]*6.283185307179586;
                    // Rotor pulse, blade harmonics and motor whine; no sampled assets.
                    const double tone=0.48*std::sin(a)+0.24*std::sin(2*a)+0.13*std::sin(3*a)+0.08*std::sin(7*a)+0.04*std::sin(13*a);
                    left+=tone*(motor%2==0?0.31:0.19);right+=tone*(motor%2==0?0.19:0.31);
                }
                noise^=noise<<13;noise^=noise>>17;noise^=noise<<5;
                const double white=(noise/4294967295.0)*2-1;
                filteredNoise+=0.14*(white-filteredNoise);
                const double air=filteredNoise*(0.08+0.24*target);
                samples[b][i*2]=static_cast<short>(std::tanh((left+air)*envelope)*13000);
                samples[b][i*2+1]=static_cast<short>(std::tanh((right+air)*envelope)*13000);
            }
            waveOutWrite(device,&buffer,sizeof(WAVEHDR));
        }
        Sleep(4);
    }
    waveOutReset(device);
    for(auto& buffer:buffers)waveOutUnprepareHeader(device,&buffer,sizeof(WAVEHDR));
    waveOutClose(device);
}
}
