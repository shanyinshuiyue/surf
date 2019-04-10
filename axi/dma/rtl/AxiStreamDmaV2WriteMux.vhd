-------------------------------------------------------------------------------
-- File       : AxiStreamDmaV2WriteMux.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming AXI write path interfaces.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiPkg.all;

entity AxiStreamDmaV2WriteMux is
   generic (
      TPD_G             : time    := 1 ns;
      AXI_READY_EN_G    : boolean := false;
      ACK_WAIT_BVALID_G : boolean := false);
   port (
      -- Clock and reset
      axiClk           : in  sl;
      axiRst           : in  sl;
      -- Slaves
      sAxiWriteMasters : in  AxiWriteMasterArray(1 downto 0);  -- CH0=WRITE, CH1=DESCR
      sAxiWriteSlaves  : out AxiWriteSlaveArray(1 downto 0);
      sAxiWriteCtrl    : out AxiCtrlArray(1 downto 0);
      -- Master
      mAxiWriteMaster  : out AxiWriteMasterType;
      mAxiWriteSlave   : in  AxiWriteSlaveType;
      mAxiWriteCtrl    : in  AxiCtrlType);
end AxiStreamDmaV2WriteMux;

architecture rtl of AxiStreamDmaV2WriteMux is

   type StateType is (
      ADDR_S,
      DATA_S,
      BRESP_S);

   type RegType is record
      index  : natural range 0 to 1;
      slaves : AxiWriteSlaveArray(1 downto 0);
      master : AxiWriteMasterType;
      state  : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      index  => 0,
      slaves => (others => AXI_WRITE_SLAVE_INIT_C),
      master => AXI_WRITE_MASTER_INIT_C,
      state  => ADDR_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   sAxiWriteCtrl <= (others => mAxiWriteCtrl);

   comb : process (axiRst, mAxiWriteSlave, r, sAxiWriteMasters) is
      variable v : RegType;
   begin
      -- Latch the current value   
      v := r;

      -- Valid/Ready Handshaking         
      for i in 1 downto 0 loop

         v.slaves(i).awready := '0';
         v.slaves(i).wready  := '0';

         if (sAxiWriteMasters(i).bready = '1') or (ACK_WAIT_BVALID_G = false) then
            v.slaves(i).bvalid := '0';
         end if;

      end loop;

      if (mAxiWriteSlave.awready = '1') or (AXI_READY_EN_G = false) then
         v.master.awvalid := '0';
      end if;

      if (mAxiWriteSlave.wready = '1') or (AXI_READY_EN_G = false) then
         v.master.wvalid := '0';
      end if;

      if (ACK_WAIT_BVALID_G) then
         v.master.bready := '0';
      else
         v.master.bready := '1';
      end if;

      -- State Machine
      case r.state is
         ----------------------------------------------------------------------
         when ADDR_S =>
            -- Check if ready to set the address
            if (v.master.awvalid = '0') then
               -- Check DMA channel 
               if (sAxiWriteMasters(0).awvalid = '1') then
                  -- ACK the valid
                  v.slaves(0).awready := '1';
                  -- Write address channel
                  v.master.awvalid    := sAxiWriteMasters(0).awvalid;
                  v.master.awaddr     := sAxiWriteMasters(0).awaddr;
                  v.master.awid       := sAxiWriteMasters(0).awid;
                  v.master.awlen      := sAxiWriteMasters(0).awlen;
                  v.master.awsize     := sAxiWriteMasters(0).awsize;
                  v.master.awburst    := sAxiWriteMasters(0).awburst;
                  v.master.awlock     := sAxiWriteMasters(0).awlock;
                  v.master.awprot     := sAxiWriteMasters(0).awprot;
                  v.master.awcache    := sAxiWriteMasters(0).awcache;
                  v.master.awqos      := sAxiWriteMasters(0).awqos;
                  v.master.awregion   := sAxiWriteMasters(0).awregion;
                  -- Set the index
                  v.index             := 0;
                  -- Next state
                  v.state             := DATA_S;
               -- Check descriptor channel
               elsif (sAxiWriteMasters(1).awvalid = '1') then
                  -- ACK the valid
                  v.slaves(1).awready := '1';
                  -- Write address channel
                  v.master.awvalid    := sAxiWriteMasters(1).awvalid;
                  v.master.awaddr     := sAxiWriteMasters(1).awaddr;
                  v.master.awid       := sAxiWriteMasters(1).awid;
                  v.master.awlen      := sAxiWriteMasters(1).awlen;
                  v.master.awsize     := sAxiWriteMasters(1).awsize;
                  v.master.awburst    := sAxiWriteMasters(1).awburst;
                  v.master.awlock     := sAxiWriteMasters(1).awlock;
                  v.master.awprot     := sAxiWriteMasters(1).awprot;
                  v.master.awcache    := sAxiWriteMasters(1).awcache;
                  v.master.awqos      := sAxiWriteMasters(1).awqos;
                  v.master.awregion   := sAxiWriteMasters(1).awregion;
                  -- Set the index
                  v.index             := 1;
                  -- Next state
                  v.state             := DATA_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_S =>
            -- Check if ready to move data
            if (v.master.wvalid = '0') and (sAxiWriteMasters(r.index).wvalid = '1') then
               -- ACK the valid
               v.slaves(r.index).wready := '1';
               -- Write data channel
               v.master.wdata           := sAxiWriteMasters(r.index).wdata;
               v.master.wlast           := sAxiWriteMasters(r.index).wlast;
               v.master.wvalid          := sAxiWriteMasters(r.index).wvalid;
               v.master.wid             := sAxiWriteMasters(r.index).wid;
               v.master.wstrb           := sAxiWriteMasters(r.index).wstrb;
               -- Check for last transfer
               if (v.master.wlast = '1') then
                  if (ACK_WAIT_BVALID_G) then
                     -- Next state
                     v.state := BRESP_S;
                  else
                     -- Next state
                     v.state := ADDR_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when BRESP_S =>
            -- Check if ready to move data
            if (v.slaves(r.index).bvalid = '0') and (mAxiWriteSlave.bvalid = '1') then
               -- ACK the valid
               v.master.bready          := '1';
               -- Write ack channel
               v.slaves(r.index).bresp  := mAxiWriteSlave.bresp;
               v.slaves(r.index).bvalid := mAxiWriteSlave.bvalid;
               v.slaves(r.index).bid    := mAxiWriteSlave.bid;
               -- Next state
               v.state                  := ADDR_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Outputs
      sAxiWriteSlaves <= r.slaves;
      for i in 1 downto 0 loop
         sAxiWriteSlaves(i).awready <= v.slaves(i).awready;
         sAxiWriteSlaves(i).wready  <= v.slaves(i).wready;
      end loop;
      mAxiWriteMaster        <= r.master;
      mAxiWriteMaster.bready <= v.master.bready;

      -- Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
