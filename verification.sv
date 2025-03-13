interface wb_intf;
  
  bit clk, rst;
  bit we, stb;
  bit [7:0] addr, wdata;
  bit [7:0] rdata;
  bit ack;
  
endinterface

class transaction;
  
  rand bit opmode;
  rand bit we;
  bit stb;
  rand bit [7:0] addr;
  rand bit [7:0] wdata;
  bit [7:0] rdata;
  bit ack;
  
  constraint opmode_c { opmode >= 0; opmode <3; }
  constraint addr_c { addr == 5; }
  constraint wdata_c { wdata > 0; wdata <= 8; }
  
  function transaction copy();
    
    copy = new();
    copy.opmode = this.opmode;
    copy.we = this.we;
    copy.stb = this.stb;
    copy.addr = this.addr;
    copy.wdata = this.wdata;
    copy.rdata = this.rdata;
    copy.ack = this.ack;
    
  endfunction
  
  function void display(input string tag);
    
    $display("[%0s] MODE: %0d, WE: %0d, STB: %0d, ADDR: %0d, WDATA: %0d, RDATA: %0d, ACK: %0d", tag, opmode, we, stb, addr, wdata, rdata, ack);
    
  endfunction
  
endclass

class generator;
  
  transaction t;
  
  mailbox #(transaction) mbx;
  
  event done;
  event parnext;
  
  int count = 0;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    t = new();
    
  endfunction
  
  task run();
    
    for(int i = 0; i < count; i++) begin
      
      assert(t.randomize()) else $display("[GEN] RANDOMIZATION FAILED");
      t.display("GEN");
      mbx.put(t.copy());
      @(parnext);
      
    end
    
    ->done;
    
  endtask
  
endclass

class driver;
  
  transaction t;
  
  mailbox #(transaction) mbx;
  
  virtual wb_intf intf;
  
  event parnext;
  
  function new(mailbox #(transaction) mbx);
    
    this.mbx = mbx;
    
  endfunction
  
  task reset();
    
    intf.rst <= 1'b1;
    intf.we <= 0;
    intf.wdata <= 0;
    intf.addr <= 0;
    intf.stb <= 0;
    repeat(10) @(posedge intf.clk);
    intf.rst <= 1'b0;
    @(posedge intf.clk);
    $display("[DRV] SYTEM RESETTED");
    
  endtask
  
  task write();
    
    @(posedge intf.clk);
    intf.we <= 1'b1;
    intf.stb <= 1'b1;
    intf.addr <= t.addr;
    intf.wdata <= t.wdata;
    $display("[DRV] DATA WRITE");
    @(posedge intf.ack);
    @(posedge intf.clk);
    intf.stb <= 1'b0;
    
  endtask
  
  task read();
    
    @(posedge intf.clk);
    intf.we <= 1'b0;
    intf.stb <= 1'b1;
    intf.addr <= t.addr;
    $display("[DRV] DATA READ");
    @(posedge intf.ack);
    @(posedge intf.clk);
    intf.stb <= 1'b0;
    
  endtask
  
  task random();
    
    @(posedge intf.clk);
    intf.we <= t.we;
    intf.stb <= 1'b1;
    intf.addr <= t.addr;
    if(t.we == 1'b1) begin
      
      intf.wdata <= t.wdata;
      
    end
    $display("[DRV] RANDOM DATA READ OR WRITE");
    @(posedge intf.ack);
    @(posedge intf.clk);
    intf.stb <= 1'b0;
    
    
  endtask
  
  task run();
    
    forever begin
      
      mbx.get(t);
      if(t.opmode == 1'b1) begin
        
        write();
        
      end
      
      else if(t.opmode == 1'b0) begin
        
        read();
        
      end
      
      else begin
        
        random();
        
      end
      
      //->parnext;
      
    end
    
  endtask
  
endclass

class monitor;
  
  transaction t;
  
  mailbox #(transaction) mbxms;
  
  virtual wb_intf intf;
  
  event parnext;
  
  function new(mailbox #(transaction) mbxms);
    
    this.mbxms = mbxms;
    
  endfunction
  
  task run();
    
    t = new();
    
    forever begin
      
      @(posedge intf.ack);
      t.addr = intf.addr;
      t.we = intf.we;
      if(intf.we == 1'b1) begin
        
        t.wdata = intf.wdata;
        $display("[MON] DATA SENT TO SCOREBOARD");
        
      end
      else begin
        
        t.rdata = intf.rdata;
        $display("[MON] DATA RECEIVED: %0d", intf.rdata);
        
      end
      mbxms.put(t);
      //->parnext;
      @(posedge intf.clk);
      
    end
    
  endtask
  
endclass

class scoreboard;
  
  transaction t;
  
  mailbox #(transaction) mbxms;
  
  event parnext;
  
  function new( mailbox #(transaction) mbxms );
    
    this.mbxms = mbxms;
    
  endfunction
  
  bit [7:0] mem[256];
  
  task run();
    
    forever begin
      
      mbxms.get(t);
      
      if(t.we == 1'b1) begin
        
        mem[t.addr] = t.wdata;
        $display("[SCO] DATA STORED IN MEM WDATA: %0d", t.wdata);
        
      end
      
      else begin
        
        if(mem[t.addr] == t.rdata) begin
          
          $display("[SCO] DATA MATCHED RDATA: %0d", t.rdata);
          
        end
        
        else begin
          
          $diplay("[SCO] DATA MISMATCHED");
          
        end
        
      end
      $display("----------------------------------------------");
      ->parnext;
      
      
    end
    
  endtask
  
endclass

class environment;
  
  transaction t;
  generator g;
  driver d;
  monitor m;
  scoreboard s;
  
  mailbox #(transaction) mbx;
  mailbox #(transaction) mbxms;
  
  event done;
  
  virtual wb_intf intf;
  
  function new(virtual wb_intf intf);
    
    mbx = new();
    mbxms = new();
    
    g = new(mbx);
    d = new(mbx);
    m = new(mbxms);
    s = new(mbxms);
    
    this.intf = intf;
    d.intf = this.intf;
    m.intf = this.intf;
    
    g.done = this.done;
    g.parnext = s.parnext;
    
    g.count = 5;
    
  endfunction
  
  task pre_test();
    
    d.reset();
    
  endtask
  
  task test();
    
    fork
      
      g.run();
      d.run();
      m.run();
      s.run();
      
    join_none
    
  endtask
  
  task post_test();
    
    wait(done.triggered);
    $finish();
    
  endtask
  
  task run();
    
    pre_test();
    test();
    post_test();
    
  endtask
  
endclass

module tb;
  
  wb_intf intf();
  
  wb_slv DUT (.clk(intf.clk), .we(intf.we), .stb(intf.stb), .ack(intf.ack), .rdata(intf.rdata), .wdata(intf.wdata), .addr(intf.addr), .rst(intf.rst));
  
  environment env;
  
  initial begin
    
    intf.clk <= 1'b0;
    
  end
  
  always #10 intf.clk <= ~intf.clk;
  
  initial begin
    
    env = new(intf);
    env.run();
    
  end
  
  initial begin
    
    $dumpfile("dump.vcd");
    $dumpvars;
    
  end
  
endmodule
