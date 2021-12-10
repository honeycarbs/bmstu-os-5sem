.586P ; разрешение трансляции всех команд в Pentium
; структура - шаблон для таблицы дескрипторов сегментов 
DESCR         STRUCT
LIM           DW 0   ; номер последнего байта сегмента, биты 0..15
BASE_L        DW 0   ; начальный линейный адрес сегмента, , биты 0..15
BASE_M        DB 0   ; средняя база, биты 1..23
ATTR_1        DB 0   ; байт атрибутов 1
ATTR_2        DB 0   ; граница (биты 24..31) и атрибуты 2, биты 24..31
BASE_H        DB 0   ; старшая база
DESCR         ENDS  
;  
; структура - шаблон для таблицы дескрипторов шлюзов
IDESCR        STRUC
OFFS_L        DW 0   ; смещение, биты 0..15
SEL           DW 0   ; селектор
CNTR          DB 0   ; хранение чиловых параметров, передающихся в стек если происходит переход на другой ур. привеелгий (здесь: не исп.)
DTYPE         DB 0   ; идентификатор дескриптора
OFFS_H        DW 0   ; смещение, биты 16..31
IDESCR        ENDS
; сегмент стека
STACK_32       SEGMENT PARA STACK 'STACK'
STACK_START    DB 256 DUP(?)
STACK_SIZE     =  $-STACK_START
STACK_32       ENDS
; сегмент данных
DATA_32       SEGMENT PARA 'DATA'
;
GDT_NULL         DESCR   <0,                0,     0,   0,         0,         0>   ; нулевой дескриптор
GDT_CODE_16      DESCR   <CODE_16_SIZE - 1, 0,     0,   98h,       0,         0>   ; дескриптор сег.кода для RM
; дескриптор для измерения объема доступной памяти (описывает сегмент размера 4гб и начало которого на 0 байте)
GDT_DATA_4GB     DESCR   <0FFFFh,           0,     0,   92h,       40h,       0>
GDT_CODE_32      DESCR   <CODE_32_SIZE - 1, 0,     0,   98h,       40h,       0>   ; дескриптор сегмента кода с 32 битными операциями
GDT_DATA_32      DESCR   <DATA_SIZE    - 1, 0,     0,   92h,       40h,       0>   ; дескриптор сегмента данных
GDT_STACK_32     DESCR   <STACK_SIZE   - 1, 0,     0,   92h,       40h,       0>
GDT_SCREEN_16    DESCR   <3999,             8000h, 0Bh, 92h,         0,       0>   ; B8000h - базовый физический адрес страницы видеостраницы
;
GDT_SIZE =$-GDT_NULL
PDESCR        DF 0 ; псевдодескриптор
; селекторы - номер дескриптора в GDT
SEL_CODE_16    EQU     8
SEL_DATA_4GB   EQU     16
SEL_CODE_32    EQU     24
SEL_DATA_32    EQU     32
SEL_STACK_32   EQU     40
SEL_SCREEN     EQU     48
;
IDT            LABEL   BYTE
;
IDESCR_0_12    IDESCR  13  DUP (<0, SEL_CODE_32, 0, 8Fh, 0>)  ; заглушки на первые 12 исключений
IDESCR_13      IDESCR           <0, SEL_CODE_32, 0, 8Fh, 0>   ; исключение общей защиты
IDESCR_14_31   IDESCR  18  DUP (<0, SEL_CODE_32, 0, 8Fh, 0>)  ; заглушки на остальные исключения
; обработчики прервыаний (NOTE: исполтзование номеров 8 и 9 некорректно по смысловой нагрузке (семинар))
INT_TIMER      IDESCR           <0, SEL_CODE_32, 0, 8Eh, 0>
INT_KEY        IDESCR           <0, SEL_CODE_32, 0, 8Eh, 0>
;
IDT_SIZE =$-IDT
IPDESCR     DF  0               ; псевдодескриптор
IPDESCR_16  DW  3FFh, 0, 0      ; псевдодескриптор для реального режима 3FF + 1 = 400h => 1024 байта => первый килобайт
; 
MASK_MASTER DB  0
MASK_SLAVE  DB  0
;
ASCIIMAP    DB 0,1Bh,'1','2','3','4','5','6','7','8','9','0','-','=',8
            DB ' ','q','w','e','r','t','y','u','i','o','p','[',']',0
            DB ' ','a','s','d','f','g','h','j','k','l',';','""',0
            DB ' ', 'z','x','c','v','b','n','m',',','.','/',0,0,0,' ',0
            DB 0,0,0,0,0,0,0,0,0,0,0,0
;
ENTER_PRESSED DB 0
TIME_CNTR     DB 0
CHAR_POS      DD 2 * (80 * 10)

MEM_POS       =  0              ; позиция на экране значения кол-ва доступной памяти
MEM_NUM_POS   =  14 + 16        ; пропустить длину строки memory(14),  16: FFFF FFFF - максимальное возможное значение
MB_POS        =  30 + 2         ;
CURSOR_POS    =  80
PARAM         =  1EH
PARAM_K       =  1BH 
;
CURSOR_SYM    =  219
CURSOR_COLOR  DB 00Eh           ; цвет курсора
SHIFT_SUB     DB 0
;
RMODE_MSG     DB 27, '[30;35mNOW IN REAL MODE. ', 27, '[0m$', '$'
PMODE_WAIT    DB 27, '[30;35mPRESS ENTER TO ENTER PROTECTED MODE:', 27, '[0m$'
PMODE_EXT     DB 27, '[30;35mNOW IN REAL MODE AGAIN. ', 27, '[0m$'
PM_MEM_COUNT  DB     'MEMORY: '
;
DATA_SIZE =$-GDT_NULL
DATA_32       ENDS
; т.р находятся в процессоре, сопоставлены с сегментными регистрами. заполняется при загрузке сегм
;
CODE_32       SEGMENT PARA PUBLIC 'CODE' USE32 ; использвоание 32-бит. адресов по умолч.
        ASSUME CS:CODE_32, DS:DATA_32, SS:STACK_32
;
PMODE_START:
    MOV  AX,  SEL_DATA_32  ; инициализация регистров для работы в реальном режиме
    MOV  DS,  AX
    MOV  AX,  SEL_SCREEN
    MOV  ES,  AX
    MOV  AX,  SEL_STACK_32
    MOV  SS,  AX
    MOV  EAX, STACK_SIZE
    MOV  ESP, EAX

    STI                   ; разрешение аппаратных прерываний
    MOV  DI,  MEM_POS
    MOV  AH,  PARAM
    XOR  ESI, ESI
    XOR  ECX, ECX
    MOV  CX,  8           ; длина "MEMORY:"
    PRINT_MEM_MSG:
        MOV  AL, PM_MEM_COUNT[ESI]
        STOSW                        ; al (символ) с параметром (ah) перемещается в область памяти es:di
        INC  ESI
    LOOP PRINT_MEM_MSG

    CALL COUNT_MEMORY_PROC

    ENTER_WAIT:
        TEST ENTER_PRESSED, 1
    JZ ENTER_WAIT

    ; ВЫХОД ИЗ ЗАЩИЩЕННОГО РЕЖИМА
    CLI                   ; запрет аппаратных маскируемые прерываний
    ; "far jump"
    DB   0EAH
    DD   OFFSET RETURN_RM
    DW   SEL_CODE_16

    DUMMY_EXCEPT PROC
        IRET
    DUMMY_EXCEPT ENDP

    EXCEPT_13    PROC
        POP EAX
    EXCEPT_13    ENDP

    TIMER_INTER  PROC USES EAX  ; uses - сохраняет контекст (push + pop)
        MOV  EDI, CURSOR_POS    ; в edi позицию для вывода
        MOV  AH,  CURSOR_COLOR
        ROR  AH,  5
        MOV  CURSOR_COLOR, AH
        MOV  AL, CURSOR_SYM     ; символ вывода
        STOSW

        ; используется только в аппаратных прерываниях для корректного завершения
        ; (разрешить обработку прерываний с меньшим приоритетом)
        MOV  AL,  20H
        OUT  20H, AL

        IRETD 
    TIMER_INTER  ENDP

    KEYBRD_INTER PROC USES EAX EBX EDX
        IN   AL, 60H            ; порт 60h при чтении содержит скан-код последней нажатой клавиши
        CMP  AL, 1CH            ; enter или нет

        JNE  SHIFT_1
        OR   ENTER_PRESSED, 1
        JMP  KEYBOARD_HANDLER

        SHIFT_1:
            CMP AL, 02AH ; скан - код ЛЕВОГО ШИФТА
            JNE SHIFT_0
            MOV BL, 32
            MOV BYTE PTR SHIFT_SUB, BL
        
        SHIFT_0:
            CMP AL, 0AAH ; скан - код ЛЕВОГО ШИФТА (отжат)
            JNE WAIT_PRINT
            MOV BL, 0
            MOV BYTE PTR SHIFT_SUB, BL
        
        WAIT_PRINT:
            CMP AL, 02AH
            JE  KEYBOARD_HANDLER

            CMP AL, 39H
            JA  KEYBOARD_HANDLER
            MOV EBX, OFFSET ASCIIMAP
            XLATB

            MOV AH,  PARAM
            MOV EBX, CHAR_POS
            CMP AL,  8
            JE  BACKSPACE_PRESSED

            CMP AL, 'a'
            JB  PRINT_KEY_PRESSED
            CMP AL, 'z'
            JA  PRINT_KEY_PRESSED

            SUB AL, BYTE PTR SHIFT_SUB
        
        PRINT_KEY_PRESSED:
            MOV ES:[EBX], AX
            ADD EBX, 2
            MOV CHAR_POS, EBX
            JMP SHORT KEYBOARD_HANDLER

        BACKSPACE_PRESSED:
            XOR AH, AH 
            MOV AL, ' '
            SUB EBX, 2
            MOV ES:[EBX], AX 
            MOV CHAR_POS, EBX
            JMP SHORT KEYBOARD_HANDLER
        
        KEYBOARD_HANDLER:
            IN  AL,  61H
            OR  AL,  80H 
            OUT 61H, AL
            AND AL, 7FH 
            OUT 61H, AL 

            MOV  AL,  20H  ; (разрешить обработку прерываний с меньшим приоритетом)
            OUT  20H, AL 

        IRETD
    KEYBRD_INTER   ENDP

    ; USES - список регистров, значения которых изменяет процедура.
    ; в начало процедуры помещается набор команд PUSH, а перед командой RET - набор
    ; команд POP, так что значения перечисленных регистров будут восстановлены
    ; Если ds не сохранить, то вернувшись обратно ds будет содержать селектор SEL_DATA_4GB.
    COUNT_MEMORY_PROC PROC USES DS EAX EBX 
        MOV  AX, SEL_DATA_4GB
        MOV  DS, AX
        ;  и в этот же момент в теневой регистр помещается дескриптор GDT_DATA_4GB
        ; в 1 мб располагается программа, ее нужно пропустить.
        MOV  EBX, 100001H           ; 2^20 + 1 байт.
        MOV  DL,  0AEh              ; Некоторое значение, с помощью которого будет осущ. проверка записи
        MOV  ECX, 0FFEFFFFEh        ; пропуск первого мегабайта

        COUNT_MEMORY_ITER:
            MOV  DH, DS:[EBX]       ; ds:[ebx] - линейный адрес вида 0 + ebx
            MOV  DS:[EBX], DL       ; запись сигнатуры по этому адресу
            CMP  DS:[EBX], DL

            ; если CMP дал отрицательный результат, то сигнатура не записалась.
            JNE  PRINT_MEMORY_COUNTED
            MOV  DS:[EBX], DH
            INC  EBX 
        LOOP COUNT_MEMORY_ITER

        PRINT_MEMORY_COUNTED:
            MOV  EAX, EBX
            XOR  EDX, EDX
            MOV  EBX, 100000H       ; 16^5 = (2^4)^5 = 2^20
            DIV  EBX                ; eax / ebx -> eax содержит кол-во МБ.

            MOV  EBX, MEM_NUM_POS
            CALL PRINT_COUNTED_MEMORY

            MOV  AH, PARAM
            MOV  EBX, MB_POS
            MOV  AL, 'H'
            MOV  ES:[EBX], AX

            RET
    COUNT_MEMORY_PROC  ENDP

    PRINT_COUNTED_MEMORY PROC USES ECX EBX EDX 
        MOV ECX, 8
        MOV DH,  PARAM

        PRINT_SYMBOL:
            MOV  DL, AL 
            AND  DL, 0FH            ; подитовое И с 00001111 - остаются последние 4 бита
            CMP  DL, 10             ; сравниваем с 10-ю
            JL   DECIM              ; меньше, то вывод цифры
            SUB  DL, 10             ; вычитаем 10 иначе 
            ADD  DL, 'A'            ; при добавлении буквы А получается шестнадцатиричная цифра, которая необходима
            JMP  LETTER
            DECIM:
                ADD  DL, '0'        ; число -> строка
            LETTER:
                MOV  ES:[EBX], DX   ; поместить вывобимый символ в видеобуфер
                ROR  EAX, 4         ; "убрать" последнюю цифру чтобы работать на след. итерации уже со следующей
                SUB  EBX, 2         ; вычет байта атрибута + байта символа
        LOOP PRINT_SYMBOL
        RET
    PRINT_COUNTED_MEMORY ENDP

    CODE_32_SIZE =$-PMODE_START
CODE_32       ENDS

CODE_16       SEGMENT PARA PUBLIC 'CODE' USE16 ; использвоание 16-бит. адресов по умолч.
        ASSUME CS:CODE_16, DS:DATA_32, SS:STACK_32

NEW_LINE:
    XOR  DX, DX
    MOV  AH, 2
    MOV  DL, 13
    INT  21H
    MOV  DL, 10
    INT  21H

    RET

CLEAR_SCREEN:
    MOV  AX, 3
    INT  10H
    
    RET 

RMODE_START:
    MOV  AX, DATA_32
    MOV  DS, AX

    MOV  AH, 09H
    LEA  DX, RMODE_MSG      ; в dx offset ds:rm_msg
    INT  21H
    CALL NEW_LINE

    MOV  AH, 09H
    LEA  DX, PMODE_WAIT
    INT  21H
    CALL NEW_LINE

    MOV  AH, 10H            ; ожидание нажатия кнопки
    INT  16H

    CALL CLEAR_SCREEN

    XOR  EAX, EAX
    MOV  AX,  CODE_16
    SHL  EAX, 4
    MOV  WORD PTR GDT_CODE_16.BASE_L, AX
    SHR  EAX, 16
    MOV  BYTE PTR GDT_CODE_16.BASE_M, AL
    MOV  BYTE PTR GDT_CODE_16.BASE_H, AH 

    MOV  AX,  CODE_32
    SHL  EAX, 4
    MOV  WORD PTR GDT_CODE_32.BASE_L, AX
    SHR  EAX, 16
    MOV  BYTE PTR GDT_CODE_32.BASE_M, AL
    MOV  BYTE PTR GDT_CODE_32.BASE_H, AH 
    
    MOV  AX,  DATA_32
    SHL  EAX, 4
    MOV  WORD PTR GDT_DATA_32.BASE_L, AX
    SHR  EAX, 16
    MOV  BYTE PTR GDT_DATA_32.BASE_M, AL
    MOV  BYTE PTR GDT_DATA_32.BASE_H, AH 

    MOV  AX,  STACK_32
    SHL  EAX, 4
    MOV  WORD PTR GDT_STACK_32.BASE_L, AX
    SHR  EAX, 16
    MOV  BYTE PTR GDT_STACK_32.BASE_M, AL
    MOV  BYTE PTR GDT_STACK_32.BASE_H, AH

    MOV  AX, DATA_32
    SHL  EAX, 4                             ; адрес сегмента, где лежит глобальная таблица дескрипторов
    ADD  EAX, OFFSET GDT_NULL               ; смещение этой таблицы в этом сегменте к начальному адресу сегмента 
    ; получается линейный адрес таблицы GDT

    MOV  DWORD PTR PDESCR + 2, EAX
    MOV  WORD  PTR PDESCR,     GDT_SIZE - 1
    LGDT FWORD PTR PDESCR

    MOV  AX, CODE_32
    MOV  ES, AX

    LEA  EAX, ES:DUMMY_EXCEPT
    MOV  IDESCR_0_12.OFFS_L, AX
    SHR  EAX, 16
    MOV  IDESCR_0_12.OFFS_H, AX

    LEA  EAX, ES:EXCEPT_13
    MOV  IDESCR_13.OFFS_L, AX
    SHR  EAX, 16
    MOV  IDESCR_13.OFFS_H, AX

    LEA  EAX, ES:DUMMY_EXCEPT
    MOV  IDESCR_14_31.OFFS_L, AX
    SHR  EAX, 16
    MOV  IDESCR_14_31.OFFS_H, AX

    LEA  EAX, ES:TIMER_INTER
    MOV  INT_TIMER.OFFS_L, AX
    SHR  EAX, 16
    MOV  INT_TIMER.OFFS_H, AX

    LEA  EAX, ES:KEYBRD_INTER
    MOV  INT_KEY.OFFS_L, AX
    SHR  EAX, 16
    MOV  INT_KEY.OFFS_H, AX

    MOV  AX, DATA_32
    SHL  EAX, 4
    ADD  EAX, OFFSET IDT 

    ; в ipdescr линейный адрес IDT для защищенного режима
    MOV  DWORD PTR IPDESCR + 2, EAX
    MOV  WORD  PTR IPDESCR, IDT_SIZE - 1

    ; сохранение масок
    IN   AL, 21H
    MOV  MASK_MASTER, AL   ; ведущий контроллер
    IN   AL, 0A1H
    MOV  MASK_SLAVE,  AL   ; ведомый контроллер

    ; перепрограммирование ведущего контроллера
    MOV  AL,  11H
    OUT  20H, AL
    MOV  AL,  32           ; размерность нового базового вектора
    OUT  21H, AL
    MOV  AL,  4
    OUT  21H, AL
    MOV  AL,  1
    OUT  21H, AL

    ; маска для ведущего контроллера
    MOV  AL,  0FCH         ; разрешить только IRQ0 И IRQ1
    OUT  21H, AL           
    
    ; маска для ведомого контроллера - запретить прерывания
    MOV  AL, 0FFH 
    OUT  0A1H, AL 

    ; открытие линии А20
    IN  AL, 92H
    OR  AL, 2
    OUT 92H, AL 

    CLI                    ; запрет аппаратных прерываний(маск.) - если этого не сделать, то в реальном режиме возникновение прерывания привело бы к отключению процессора
    LIDT FWORD PTR IPDESCR 

    ; запрет немаскируемых прерываний
    MOV  AL,  80H 
    OUT  70H, AL

    ; ПЕРЕХОД В ЗАЩИЩЕННЫЙ РЕЖИМ
    MOV  EAX, CR0 
    OR   EAX, 1             ; установка в 1 бита ЗР
    MOV  CR0, EAX           ; перевод процессора в ЗР

    DB 66H    ; префикс изменения разрядности операнда (меняет на противоположный).
    DB 0EAH   ; код команды far jmp.
    DD OFFSET PMODE_START
    DW SEL_CODE_32

RETURN_RM:
    MOV  EAX, CR0
    AND  AL,  0FEH          ; cброс 1 бита ЗР
    MOV  CR0, EAX 


    DB   0EAH 
    DW   OFFSET GO
    DW   CODE_16

GO:
    MOV  AX, DATA_32
    MOV  DS, AX 
    MOV  AX, CODE_32
    MOV  ES, AX
    MOV  AX, STACK_32
    MOV  SS, AX
    MOV  AX, STACK_SIZE
    MOV  SP, AX

    ; перепрограммирование ведущего контроллера
    MOV  AL,  11H
    OUT  20H, AL
    MOV  AL,  8            ; размерность нового базового вектора
    OUT  21H, AL
    MOV  AL,  4
    OUT  21H, AL
    MOV  AL,  1
    OUT  21H, AL

    MOV  AL, MASK_MASTER
    OUT  21H, AL
    MOV  AL, MASK_SLAVE
    OUT  0A1H, AL 

    ; восстанавливаем вектор прерываний
    LIDT FWORD PTR IPDESCR_16

    ; закрытие линии А20
    IN  AL, 70H
    AND AL, 7FH 
    OUT 70H, AL 

    STI  ; Резрешить аппаратные прерывания    

    CALL CLEAR_SCREEN

    MOV AH, 09H
    LEA DX, PMODE_EXT
    INT 21H 
    CALL NEW_LINE

    MOV AX, 4C00H
    INT 21H 

    CODE_16_SIZE = $-RMODE_START
CODE_16         ENDS 

END RMODE_START 




    





    



