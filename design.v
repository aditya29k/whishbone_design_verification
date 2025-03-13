module wb_slv
  (
    
    input clk, rst,
    input we, stb,
    input [7:0] addr, wdata,
    output reg [7:0] rdata,
    output reg ack
    
  );
  
  reg [7:0] mem [256];
  reg [7:0] temp;
  
  typedef enum bit [1:0] { idle = 0, check_mode = 1, write = 2, read = 3 } state_type;
  state_type state;
  
  always @(posedge clk) begin
    
    if(rst) begin
      
      state <= idle;
      rdata <= 0;
      ack <= 1'b0;
      
      for(int i = 0; i < 256; i ++) begin
        
        mem[i] <= 0;
        
      end
      
    end
    
    else begin
      
      case(state)
        
        idle: begin
          
          state <= check_mode;
          ack <= 0;
          temp <= 0;
          
        end
        
        check_mode: begin
          
          if(stb && we) begin
            
            state <= write;
            temp <= wdata;
            
          end
          
          else if(stb && !we) begin
            
            state <= read;
            temp <= mem[addr];
            
          end
          
        end
        
        write: begin
          
          mem[addr] <= temp;
          ack <= 1'b1;
          state <= idle;
          
        end
        
        read: begin
          
          rdata <= temp;
          ack <= 1'b1;
          state <= idle;
          
        end
        
        default: state <= idle;
        
      endcase
      
    end
    
  end
  
endmodule
