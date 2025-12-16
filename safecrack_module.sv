// Os comentários em português são da equipe

module safecrack_fsm (
    // declaração dos inputs e outputs
    input  logic       clk,
    input  logic       rstn,
    input  logic [2:0] btn,     // botões (valor armazenado em 3 bits)
    output logic       led_g_1, // representa o 1° LED verde (output: 1 a partir do estado inicial)
    output logic       led_g_2, // representa o 2° LED verde (output: 1 quando o usuário acertar o 1° botão)
    output logic       led_g_3, // representa o 3° LED verde (output: 1 quando o usuário acertar o 2° botão)
    output logic       led_r    // representa o LED vermelho (output: 1 quando o usuário errar o botão)
);
    // one-hot encoding
    typedef enum logic [4:0] { 
        S0            = 5'b00001,  // estado inicial (1 LED verde aceso)
        S1            = 5'b00010,  // 1° botão correto (2 LEDs verdes acesos)
        S2            = 5'b00100,  // 2° botão correto (3 LEDs verdes acesos)
        ERROR         = 5'b01000,  // botão errado (1 LED vermelho aceso. Volta ao estado inicial após 3s)
        UNLOCKED      = 5'b10000   // 3° botão correto (todos os LEDs verdes acesos por 5s, depois volta a S0)
    } state_t;

    state_t state, next_state; // declarando o estado atual e o próximo
    // declarando os botões
    logic [2:0] btn_prev, btn_edge, btn_pos;
    logic       any_btn_edge;

    localparam int BLINK_DELAY = 50_000_000;        // 1 second delay at 50MHz clock
    localparam int BLINK_DELAY_3 = BLINK_DELAY * 3; // 3 segundos de delay no clock
    localparam int BLINK_DELAY_5 = BLINK_DELAY * 5; // 5 segundos de delay no clock
    // duas variáveis de delay para contar 3 e 5 segundos, respectivamente
    logic [$clog2(BLINK_DELAY_3) - 1:0] delay_cnt_3_seg, next_delay_cnt_3_seg;
    logic [$clog2(BLINK_DELAY_5) - 1:0] delay_cnt_5_seg, next_delay_cnt_5_seg;

    // tratamento dos inputs do botão
    always_comb begin
       btn_pos	= ~btn; // invert buttons to active high
       btn_edge = btn_pos & ~btn_prev; // get 0 -> 1 edges
       any_btn_edge = (|btn_edge); // any button edge detected
    end 
     
    // sequential logic
    // ocorre sincronizada com o clock
    always_ff @(posedge clk or negedge rstn) begin
        // se reset == 1
        if (~rstn) begin
            btn_prev          <= 3'b000;
            delay_cnt_3_seg   <= BLINK_DELAY_3;
            delay_cnt_5_seg   <= BLINK_DELAY_5;
            state             <= S0;
        end
        // se não, atualiza o botão, contadores de delay e estado atuais
        else begin
            btn_prev          <= btn_pos;
            delay_cnt_3_seg   <= next_delay_cnt_3_seg;
            delay_cnt_5_seg   <= next_delay_cnt_5_seg;
            state             <= next_state;
        end
    end

    // transition logic (lógica combinacional. Ocorre o tempo todo)
    always_comb begin
        // atualiza os próximos estados e contadores para a lógica sequencial
        next_state = state;
        next_delay_cnt_3_seg = delay_cnt_3_seg;
        next_delay_cnt_5_seg = delay_cnt_5_seg;

        // "switch-case" para verificar o estado atual e o que acontece nele
        unique case (state)
            S0: begin
                    if (btn_edge == 3'b001) next_state = S1;   // botão correto: próximo estado
                    else if (any_btn_edge) next_state = ERROR; // botão incorreto: erro
                    else next_state = S0;					   // nenhum botão pressionado: nada acontece
                end
            S1: begin
                    if (btn_edge == 3'b010) next_state = S2;
                    else if (any_btn_edge) next_state = ERROR;
                    else next_state = S1;
                end
            S2: begin
                    if (btn_edge == 3'b100) next_state = UNLOCKED; // botão correto -> cofre desbloqueado
                    else if (any_btn_edge) next_state = ERROR;
                    else next_state = S2;
                end
            ERROR: begin
                // loop para o delay de 3s
                if (delay_cnt_3_seg > 0) begin
                    next_delay_cnt_3_seg = delay_cnt_3_seg - 1;
                end
                // quando o loop acabar, a máquina volta ao estado inicial e o contador é resetado
                else begin
                    next_state = S0;
                    next_delay_cnt_3_seg = BLINK_DELAY_3;
                end
            end
            UNLOCKED: begin
                // loop para o delay de 5s
                if (delay_cnt_5_seg > 0) begin
                    next_delay_cnt_5_seg = delay_cnt_5_seg - 1;
                end
                // quando o loop acabar, a máquina volta ao estado inicial e o contador é resetado
                else begin
                    next_state = S0;
                    next_delay_cnt_5_seg = BLINK_DELAY_5; // reset delay counter
                end
            end
            
            default: next_state = S0;
        endcase

        // resetando os dois contadores novamente antes do estado trocar pra ERROR ou UNLOCKED
        // (caso de apertar outro botão antes do tempo de delay acabar)

        if (state != ERROR && next_state == ERROR) begin
            next_delay_cnt_3_seg = BLINK_DELAY_3;
        end

        if (state != UNLOCKED && next_state == UNLOCKED) begin
            next_delay_cnt_5_seg = BLINK_DELAY_5;
        end
    end

    // tratamento dos outputs
    always_comb begin
        // os LEDs verdes vão gradativamente acendendo, conforme o usuário for acertando os botões
        led_g_1 = (state != ERROR);
        led_g_2 = (state != ERROR & state != S0);
        led_g_3 = (state == S2 | state == UNLOCKED);
        // caso ele erre, apenas o LED vermelho ficará aceso
        led_r   = (state == ERROR);
    end

endmodule