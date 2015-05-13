-------------------------------------------------------------------------------
-- Title      : SSI PCIe Core
-------------------------------------------------------------------------------
-- File       : SsiPcieTlpOutbound.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-22
-- Last update: 2015-04-22
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: SSI PCIe Outbound TLP Packet Controller
-- Note: Memory IO bursting not supported.  
--       Only one 32-bit word transaction at a time.

-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPciePkg.all;

entity SsiPcieTlpOutbound is
   generic (
      TPD_G      : time                   := 1 ns;
      DMA_SIZE_G : positive range 1 to 16 := 1);
   port (
      -- PCIe Interface
      sAsixHdr      : in  PcieHdrType;
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      -- Outbound DMA Interface
      regObMaster   : out AxiStreamMasterType;
      regObSlave    : in  AxiStreamSlaveType;
      dmaTxObMaster : out AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      dmaTxObSlave  : in  AxiStreamSlaveArray(DMA_SIZE_G-1 downto 0);
      -- Clock and Resets
      pciClk        : in  sl;
      pciRst        : in  sl);       
end SsiPcieTlpOutbound;

architecture rtl of SsiPcieTlpOutbound is

   type StateType is (
      IDLE_S,
      DMA_S);   

   type RegType is record
      chPntr        : natural range 0 to DMA_SIZE_G-1;
      sAxisSlave    : AxiStreamSlaveType;
      regObMaster   : AxiStreamMasterType;
      dmaTxObMaster : AxiStreamMasterArray(DMA_SIZE_G-1 downto 0);
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      chPntr        => 0,
      sAxisSlave    => AXI_STREAM_SLAVE_INIT_C,
      regObMaster   => AXI_STREAM_MASTER_INIT_C,
      dmaTxObMaster => (others => AXI_STREAM_MASTER_INIT_C),
      state         => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dmaTag     : slv(7 downto 0);
   signal dmaTagPntr : natural range 0 to 127;
   
   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   dmaTag     <= sAxisMaster.tData(79 downto 72);
   dmaTagPntr <= conv_integer(dmaTag(7 downto 1));

   comb : process (dmaTag, dmaTagPntr, dmaTxObSlave, pciRst, r, regObSlave, sAsixHdr, sAxisMaster) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Default to not ready for data
      v.sAxisSlave.tReady := '0';

      -- Update REG tValid register
      if regObSlave.tReady = '1' then
         v.regObMaster.tValid := '0';
      end if;

      -- Update DMA tValid registers
      for i in 0 to DMA_SIZE_G-1 loop
         if dmaTxObSlave(i).tReady = '1' then
            v.dmaTxObMaster(i).tValid := '0';
         end if;
      end loop;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for new data
            if (sAxisMaster.tValid = '1') and (v.regObMaster.tValid = '0') then
               -- Check for SOF and correct request ID
               if (sAxisMaster.tUser(1) = '1') then
                  -- Check for memory read or write always goes to reg block
                  -- Note: Memory IO bursting not supported. Only one 32-bit word transaction at a time.    
                  if (sAsixHdr.xType = "00000") and (sAxisMaster.tLast = '1') and (sAxisMaster.tUser(1) = '1') then
                     -- Accept the data
                     v.sAxisSlave.tReady := '1';
                     v.regObMaster       := sAxisMaster;
                  -- Else check for a a completion header with data payload and for TX DMA tag
                  elsif (sAsixHdr.xType = "01010") and (dmaTag(0) = '1') and (dmaTagPntr < DMA_SIZE_G) then
                     -- Set the channel pointer
                     v.chPntr := dmaTagPntr;
                     -- Check if target is ready for data
                     if v.dmaTxObMaster(dmaTagPntr).tValid = '0' then
                        -- Ready for data
                        v.sAxisSlave.tReady         := '1';
                        v.dmaTxObMaster(dmaTagPntr) := sAxisMaster;
                        -- Check for not(tLast)
                        if sAxisMaster.tLast = '0' then
                           -- Next state
                           v.state := DMA_S;
                        end if;
                     else
                        -- Next state
                        v.state := DMA_S;
                     end if;
                  else
                     -- Blow off the data
                     v.sAxisSlave.tReady := '1';
                  end if;
               else
                  -- Blow off the data
                  v.sAxisSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when DMA_S =>
            -- Check if target is ready for data
            if (v.dmaTxObMaster(r.chPntr).tValid = '0') and (sAxisMaster.tValid = '1') then
               -- Ready for data
               v.sAxisSlave.tReady       := '1';
               v.dmaTxObMaster(r.chPntr) := sAxisMaster;
               -- Check for tLast
               if sAxisMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave    <= v.sAxisSlave;
      dmaTxObMaster <= r.dmaTxObMaster;
      regObMaster   <= r.regObMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
