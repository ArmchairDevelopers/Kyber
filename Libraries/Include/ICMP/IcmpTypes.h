// Structures required to use functions in ICMP.DLL

typedef struct {
    unsigned char Ttl;                         
    unsigned char Tos;                         
    unsigned char Flags;                       
    unsigned char OptionsSize;
    unsigned char *OptionsData;                
} IP_OPTION_INFORMATION, * PIP_OPTION_INFORMATION;

typedef struct {
    DWORD Address;                             
    unsigned long  Status;       
    unsigned long  RoundTripTime;
    unsigned short DataSize;     
    unsigned short Reserved;     
    void *Data;                  
    IP_OPTION_INFORMATION Options;             
} IP_ECHO_REPLY, * PIP_ECHO_REPLY;

